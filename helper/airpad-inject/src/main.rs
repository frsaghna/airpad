use airpad_inject::{ProtocolEvent, VirtualInput};
use std::env;
use std::fs::{self, Permissions};
use std::io::{BufRead, BufReader};
use std::os::unix::fs::PermissionsExt;
use std::os::unix::net::UnixListener;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;

fn get_socket_path() -> PathBuf {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    let dir = Path::new(&runtime_dir).join("airpad");
    if !dir.exists() {
        let _ = fs::create_dir_all(&dir);
        let _ = fs::set_permissions(&dir, Permissions::from_mode(0o700));
    }
    dir.join("inject.sock")
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    eprintln!("[airpad-inject] Starting Linux input helper...");

    let socket_path = get_socket_path();
    if socket_path.exists() {
        eprintln!("[airpad-inject] Cleaning up existing socket at {:?}", socket_path);
        let _ = fs::remove_file(&socket_path);
    }

    let mut virtual_input = match VirtualInput::new() {
        Ok(vi) => {
            eprintln!("[airpad-inject] Virtual input device registered via /dev/uinput");
            vi
        }
        Err(e) => {
            eprintln!("[airpad-inject] ERROR: Failed to create virtual input device: {e}");
            eprintln!("[airpad-inject] Hint: Make sure current user is in 'input' group and /dev/uinput has rw permissions.");
            return Err(e.into());
        }
    };

    let listener = UnixListener::bind(&socket_path)?;
    // Enforce 0600 permissions on the socket
    fs::set_permissions(&socket_path, Permissions::from_mode(0o600))?;
    eprintln!("[airpad-inject] Listening on Unix socket {:?} (mode 0600)", socket_path);

    // Setup signal handler for clean shutdown
    let running = Arc::new(AtomicBool::new(true));
    let r = running.clone();

    ctrlc::set_handler(move || {
        eprintln!("\n[airpad-inject] Shutdown signal received. Stopping...");
        r.store(false, Ordering::SeqCst);
    })?;

    // Set listener to non-blocking so we can check shutdown signal
    listener.set_nonblocking(true)?;

    while running.load(Ordering::SeqCst) {
        match listener.accept() {
            Ok((stream, _addr)) => {
                eprintln!("[airpad-inject] Client connected");
                let _ = stream.set_nonblocking(false);
                let reader = BufReader::new(stream);

                for line in reader.lines() {
                    if !running.load(Ordering::SeqCst) {
                        break;
                    }
                    match line {
                        Ok(line_str) => {
                            let trimmed = line_str.trim();
                            if trimmed.is_empty() {
                                continue;
                            }
                            match serde_json::from_str::<ProtocolEvent>(trimmed) {
                                Ok(event) => {
                                    if let Err(e) = virtual_input.handle_event(&event) {
                                        eprintln!("[airpad-inject] Event handling error: {e}");
                                    }
                                }
                                Err(e) => {
                                    eprintln!("[airpad-inject] Invalid event JSON: {e} ('{trimmed}')");
                                }
                            }
                        }
                        Err(e) => {
                            eprintln!("[airpad-inject] Read error / client disconnected: {e}");
                            break;
                        }
                    }
                }

                // Client disconnected -> Release all held keys and buttons!
                eprintln!("[airpad-inject] Client disconnected. Releasing all held keys and buttons...");
                let _ = virtual_input.release_all();
            }
            Err(ref e) if e.kind() == std::io::ErrorKind::WouldBlock => {
                std::thread::sleep(std::time::Duration::from_millis(50));
            }
            Err(e) => {
                eprintln!("[airpad-inject] Accept error: {e}");
                std::thread::sleep(std::time::Duration::from_millis(100));
            }
        }
    }

    let _ = virtual_input.release_all();
    let _ = fs::remove_file(&socket_path);
    eprintln!("[airpad-inject] Exited cleanly.");
    Ok(())
}
