import 'package:common/model/device.dart';
import 'package:common/model/dto/multicast_dto.dart';

class ChatPeerDto {
  final String alias;
  final String version;
  final String? deviceModel;
  final DeviceType deviceType;
  final String fingerprint;
  final int port;
  final ProtocolType protocol;

  const ChatPeerDto({
    required this.alias,
    required this.version,
    required this.deviceModel,
    required this.deviceType,
    required this.fingerprint,
    required this.port,
    required this.protocol,
  });

  factory ChatPeerDto.fromMap(Map<String, dynamic> map) {
    return ChatPeerDto(
      alias: map['alias'] as String,
      version: map['version'] as String,
      deviceModel: map['deviceModel'] as String?,
      deviceType: DeviceType.values.firstWhere(
        (type) => type.name == map['deviceType'],
        orElse: () => DeviceType.desktop,
      ),
      fingerprint: map['fingerprint'] as String,
      port: map['port'] as int,
      protocol: ProtocolType.values.firstWhere(
        (protocol) => protocol.name == map['protocol'],
        orElse: () => ProtocolType.https,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'alias': alias,
      'version': version,
      'deviceModel': deviceModel,
      'deviceType': deviceType.name,
      'fingerprint': fingerprint,
      'port': port,
      'protocol': protocol.name,
    };
  }

  Device toDevice(String ip) {
    return Device(
      signalingId: null,
      ip: ip,
      version: version,
      port: port,
      https: protocol == ProtocolType.https,
      fingerprint: fingerprint,
      alias: alias,
      deviceModel: deviceModel,
      deviceType: deviceType,
      download: false,
      discoveryMethods: {HttpDiscovery(ip: ip)},
    );
  }
}
