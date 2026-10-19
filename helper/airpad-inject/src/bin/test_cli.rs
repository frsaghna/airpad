use std::env;
use std::io::Write;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::thread::sleep;
use std::time::Duration;

fn get_socket_path() -> PathBuf {
    let runtime_dir = env::var("XDG_RUNTIME_DIR").unwrap_or_else(|_| "/tmp".into());
    Path::new(&runtime_dir).join("airpad").join("inject.sock")
}

fn send_event(stream: &mut UnixStream, json: &str) -> std::io::Result<()> {
    stream.write_all(json.as_bytes())?;
    stream.write_all(b"\n")?;
    stream.flush()?;
    Ok(())
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let socket_path = get_socket_path();
    println!("[airpad-test-cli] Connecting to helper socket at {:?}", socket_path);

    let mut stream = match UnixStream::connect(&socket_path) {
        Ok(s) => s,
        Err(e) => {
            eprintln!("[airpad-test-cli] Failed to connect: {e}");
            eprintln!("[airpad-test-cli] Ensure 'airpad-inject' is running first.");
            return Err(e.into());
        }
    };

    println!("[airpad-test-cli] Connected successfully!");

    // 1. Move cursor in a square: Right -> Down -> Left -> Up
    println!("[airpad-test-cli] Action 1: Moving cursor in a 200px square...");
    let steps = 40;
    let step_delay = Duration::from_millis(16); // ~60 Hz

    // Right
    for _ in 0..steps {
        send_event(&mut stream, r#"{"type":"move","dx":5.0,"dy":0.0}"#)?;
        sleep(step_delay);
    }
    // Down
    for _ in 0..steps {
        send_event(&mut stream, r#"{"type":"move","dx":0.0,"dy":5.0}"#)?;
        sleep(step_delay);
    }
    // Left
    for _ in 0..steps {
        send_event(&mut stream, r#"{"type":"move","dx":-5.0,"dy":0.0}"#)?;
        sleep(step_delay);
    }
    // Up
    for _ in 0..steps {
        send_event(&mut stream, r#"{"type":"move","dx":0.0,"dy":-5.0}"#)?;
        sleep(step_delay);
    }

    sleep(Duration::from_millis(300));

    // 2. Click left mouse button
    println!("[airpad-test-cli] Action 2: Sending left click...");
    send_event(&mut stream, r#"{"type":"click","button":"left","count":1}"#)?;

    sleep(Duration::from_millis(300));

    // 3. Type "hello "
    println!("[airpad-test-cli] Action 3: Typing 'hello '...");
    send_event(&mut stream, r#"{"type":"text","value":"hello "}"#)?;

    sleep(Duration::from_millis(300));

    // 4. Test held key release on disconnect:
    // Send a key down event without key up to prove helper releases it on socket drop
    println!("[airpad-test-cli] Action 4: Testing key down (ShiftLeft)...");
    send_event(&mut stream, r#"{"type":"key","code":"ShiftLeft","state":"down"}"#)?;
    sleep(Duration::from_millis(100));

    println!("[airpad-test-cli] Disconnecting socket now (verifying helper auto-releases held keys)...");
    drop(stream);

    println!("[airpad-test-cli] All test actions sent successfully!");
    Ok(())
}
