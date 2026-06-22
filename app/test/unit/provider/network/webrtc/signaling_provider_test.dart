import 'package:localsend_app/provider/network/webrtc/signaling_provider.dart';
import 'package:localsend_app/rust/api/model.dart' as rust;
import 'package:localsend_app/rust/api/webrtc.dart';
import 'package:test/test.dart';
import 'package:uuid/uuid.dart';

void main() {
  test('visibleSignalingPeers excludes the current signaling client', () {
    final self = _client(
      id: '00000000-0000-0000-0000-000000000001',
      token: 'self-token',
    );
    final peer = _client(
      id: '00000000-0000-0000-0000-000000000002',
      token: 'peer-token',
    );

    final visible = visibleSignalingPeers(
      client: self,
      peers: [self, peer],
    ).toList();

    expect(visible, [peer]);
  });
}

ClientInfo _client({
  required String id,
  required String token,
}) {
  return ClientInfo(
    id: UuidValue.fromString(id),
    alias: 'PC_Mobile',
    version: '2.1',
    deviceModel: 'Windows',
    deviceType: rust.DeviceType.desktop,
    token: token,
  );
}
