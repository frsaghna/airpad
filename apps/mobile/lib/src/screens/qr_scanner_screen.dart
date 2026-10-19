import 'package:airpad_core/airpad_core.dart';
import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Fullscreen monochrome QR code scanner for pairing with AIRPAD desktop receiver.
class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
  );

  bool _isProcessing = false;
  String? _errorMessage;

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;

    for (final barcode in capture.barcodes) {
      final raw = barcode.rawValue;
      if (raw != null && raw.isNotEmpty) {
        final payload = QrPairingPayload.tryParse(raw);
        if (payload != null) {
          setState(() {
            _isProcessing = true;
          });
          Navigator.of(context).pop(payload);
          return;
        } else if (raw.startsWith('airpad://')) {
          setState(() {
            _errorMessage = 'Invalid QR code format';
          });
        }
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AirTheme.black,
      appBar: AppBar(
        title: const Text('SCAN DESKTOP QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.flash_on_outlined),
            onPressed: () => _controller.toggleTorch(),
            tooltip: 'Toggle Flash',
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios_outlined),
            onPressed: () => _controller.switchCamera(),
            tooltip: 'Switch Camera',
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt_outlined, size: 48, color: AirTheme.white),
                      const SizedBox(height: 16),
                      Text(
                        'CAMERA ERROR: ${error.errorCode.name}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.errorDetails?.message ?? 'Ensure camera permissions are granted.',
                        style: const TextStyle(color: AirTheme.gray500),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      AirButton(
                        label: 'CLOSE',
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Monochrome Viewfinder Overlay
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AirTheme.white,
                  width: 2.0,
                ),
                borderRadius: BorderRadius.circular(AirpadTokens.cornerRadius),
              ),
              child: Stack(
                children: [
                  // Corner accents
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(width: 16, height: 2, color: AirTheme.white),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(width: 2, height: 16, color: AirTheme.white),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(width: 16, height: 2, color: AirTheme.white),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(width: 2, height: 16, color: AirTheme.white),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(width: 16, height: 2, color: AirTheme.white),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Container(width: 2, height: 16, color: AirTheme.white),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(width: 16, height: 2, color: AirTheme.white),
                  ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(width: 2, height: 16, color: AirTheme.white),
                  ),
                ],
              ),
            ),
          ),

          // Instructions at bottom
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: AirCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'ALIGN WITH DESKTOP QR CODE',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Open the AIRPAD window on your PC and click "Pairing QR"',
                    style: TextStyle(
                      fontSize: 13,
                      color: AirTheme.gray500,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        color: AirTheme.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
