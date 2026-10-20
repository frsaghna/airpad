import 'package:airpad_ui/airpad_ui.dart';
import 'package:flutter/material.dart';
import 'src/screens/discover_screen.dart';
import 'src/services/mobile_services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final services = MobileServices();
  runApp(AirpadMobileApp(services: services));
}

/// Root widget for the AIRPAD mobile controller app.
class AirpadMobileApp extends StatefulWidget {
  const AirpadMobileApp({
    super.key,
    required this.services,
  });

  final MobileServices services;

  @override
  State<AirpadMobileApp> createState() => _AirpadMobileAppState();
}

class _AirpadMobileAppState extends State<AirpadMobileApp> {
  late Future<void> _initFuture;

  @override
  void initState() {
    super.initState();
    _initFuture = widget.services.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.services,
      builder: (context, _) {
        final isDark = widget.services.isDark;

        return MaterialApp(
          title: 'AIRPAD',
          debugShowCheckedModeBanner: false,
          theme: isDark ? AirTheme.darkTheme : AirTheme.lightTheme,
          home: FutureBuilder<void>(
            future: _initFuture,
            builder: (context, snapshot) {
              final colors = AirColors.of(context);
              if (snapshot.connectionState != ConnectionState.done) {
                return Scaffold(
                  backgroundColor: colors.bg,
                  body: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'AIRPAD',
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 24,
                            letterSpacing: 4.0,
                            color: colors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const AirStatusBadge(
                          type: AirStatusType.idle,
                          customLabel: 'INITIALIZING...',
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (snapshot.hasError) {
                return Scaffold(
                  backgroundColor: colors.bg,
                  body: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.error_outline, size: 48, color: colors.textPrimary),
                          const SizedBox(height: 16),
                          Text(
                            'STARTUP ERROR',
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: colors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            snapshot.error.toString(),
                            style: TextStyle(color: colors.textSecondary),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          AirButton(
                            label: 'RETRY',
                            onPressed: () {
                              setState(() {
                                _initFuture = widget.services.initialize();
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return DiscoverScreen(services: widget.services);
            },
          ),
        );
      },
    );
  }
}
