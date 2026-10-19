/// Core library for Airpad containing protocol models, design tokens, crypto, discovery, sessions, touchpad, and keyboard logic.
library airpad_core;

export 'src/crypto/device_identity.dart';
export 'src/crypto/trust_store.dart';
export 'src/desktop/inject_client.dart';
export 'src/discovery/discovery_manager.dart';
export 'src/discovery/http_fallback_service.dart';
export 'src/discovery/multicast_service.dart';
export 'src/keyboard/keyboard_state.dart';
export 'src/models/device.dart';
export 'src/models/event.dart';
export 'src/models/pairing.dart';
export 'src/session/pairing_manager.dart';
export 'src/session/tls_session_client.dart';
export 'src/session/tls_session_server.dart';
export 'src/tokens/design_tokens.dart';
export 'src/touchpad/move_coalescer.dart';
export 'src/touchpad/touchpad_processor.dart';
export 'src/utils/alias_generator.dart';
