import 'dart:convert';
import 'package:meta/meta.dart';

/// Sealed hierarchy of pairing control messages sent during session setup.
@immutable
sealed class PairingMessage {
  const PairingMessage();

  String get type;
  Map<String, dynamic> toJson();

  String toJsonString() => jsonEncode(toJson());

  static PairingMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String?;
    switch (type) {
      case 'pair_prompt':
        return PairPromptMessage.fromJson(json);
      case 'pair_confirm':
        return PairConfirmMessage.fromJson(json);
      case 'pair_ok':
        return PairOkMessage.fromJson(json);
      case 'pair_reject':
        return PairRejectMessage.fromJson(json);
      case 'pair_qr':
        return PairQrMessage.fromJson(json);
      default:
        throw FormatException('Unknown pairing message type: $type');
    }
  }

  static PairingMessage fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Expected JSON object for pairing message');
    }
    return PairingMessage.fromJson(decoded);
  }
}

/// Prompt sent by desktop to phone containing the 6-digit code.
@immutable
final class PairPromptMessage extends PairingMessage {
  const PairPromptMessage({
    required this.code,
    required this.fingerprint,
  });

  final String code;
  final String fingerprint;

  @override
  String get type => 'pair_prompt';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code,
        'fingerprint': fingerprint,
      };

  factory PairPromptMessage.fromJson(Map<String, dynamic> json) {
    return PairPromptMessage(
      code: json['code'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairPromptMessage &&
          code == other.code &&
          fingerprint == other.fingerprint;

  @override
  int get hashCode => code.hashCode ^ fingerprint.hashCode;

  @override
  String toString() => 'PairPromptMessage(code: $code, fingerprint: $fingerprint)';
}

/// Confirmation message sent when pairing is confirmed.
@immutable
final class PairConfirmMessage extends PairingMessage {
  const PairConfirmMessage({
    required this.alias,
    required this.fingerprint,
  });

  final String alias;
  final String fingerprint;

  @override
  String get type => 'pair_confirm';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'alias': alias,
        'fingerprint': fingerprint,
      };

  factory PairConfirmMessage.fromJson(Map<String, dynamic> json) {
    return PairConfirmMessage(
      alias: json['alias'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairConfirmMessage &&
          alias == other.alias &&
          fingerprint == other.fingerprint;

  @override
  int get hashCode => alias.hashCode ^ fingerprint.hashCode;
}

/// Sent by receiver to confirm successful pairing.
@immutable
final class PairOkMessage extends PairingMessage {
  const PairOkMessage();

  @override
  String get type => 'pair_ok';

  @override
  Map<String, dynamic> toJson() => {'type': type};

  factory PairOkMessage.fromJson(Map<String, dynamic> json) =>
      const PairOkMessage();

  @override
  bool operator ==(Object other) => other is PairOkMessage;

  @override
  int get hashCode => type.hashCode;
}

/// Sent when pairing is rejected or times out.
@immutable
final class PairRejectMessage extends PairingMessage {
  const PairRejectMessage({this.reason = 'Pairing rejected'});

  final String reason;

  @override
  String get type => 'pair_reject';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'reason': reason,
      };

  factory PairRejectMessage.fromJson(Map<String, dynamic> json) {
    return PairRejectMessage(
      reason: json['reason'] as String? ?? 'Pairing rejected',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairRejectMessage && reason == other.reason;

  @override
  int get hashCode => reason.hashCode;
}

/// Sent by phone when connecting via QR code.
@immutable
final class PairQrMessage extends PairingMessage {
  const PairQrMessage({
    required this.code,
    required this.alias,
    required this.fingerprint,
  });

  final String code;
  final String alias;
  final String fingerprint;

  @override
  String get type => 'pair_qr';

  @override
  Map<String, dynamic> toJson() => {
        'type': type,
        'code': code,
        'alias': alias,
        'fingerprint': fingerprint,
      };

  factory PairQrMessage.fromJson(Map<String, dynamic> json) {
    return PairQrMessage(
      code: json['code'] as String? ?? '',
      alias: json['alias'] as String? ?? '',
      fingerprint: json['fingerprint'] as String? ?? '',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PairQrMessage &&
          code == other.code &&
          alias == other.alias &&
          fingerprint == other.fingerprint;

  @override
  int get hashCode => code.hashCode ^ alias.hashCode ^ fingerprint.hashCode;
}
