import 'package:common/model/device.dart';
import 'package:localsend_app/model/state/nearby_devices_state.dart';
import 'package:test/test.dart';

void main() {
  test('allDevices merges LAN and signaling entries with the same fingerprint', () {
    final state = NearbyDevicesState(
      runningFavoriteScan: false,
      runningIps: const {},
      devices: {
        '192.168.1.10': _device(
          fingerprint: 'peer-fingerprint',
          ip: '192.168.1.10',
          methods: {const MulticastDiscovery()},
        ),
      },
      signalingDevices: {
        'peer-fingerprint': {
          _device(
            fingerprint: 'peer-fingerprint',
            signalingId: 'signaling-id',
            methods: {
              const SignalingDiscovery(signalingServer: 'wss://example.test'),
            },
          ),
        },
      },
    );

    final devices = state.allDevices.values.toList();

    expect(devices, hasLength(1));
    expect(devices.single.ip, '192.168.1.10');
    expect(devices.single.signalingId, 'signaling-id');
    expect(
      devices.single.transmissionMethods,
      {TransmissionMethod.http, TransmissionMethod.webrtc},
    );
  });
}

Device _device({
  required String fingerprint,
  required Set<DiscoveryMethod> methods,
  String? ip,
  String? signalingId,
}) {
  return Device(
    signalingId: signalingId,
    ip: ip,
    version: '2.1',
    port: ip == null ? -1 : 53317,
    https: false,
    fingerprint: fingerprint,
    alias: 'PC_Mobile',
    deviceModel: 'Windows',
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: methods,
  );
}
