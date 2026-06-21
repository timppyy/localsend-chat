import 'package:common/constants.dart';
import 'package:common/model/device.dart';
import 'package:common/model/session_status.dart';
import 'package:localsend_app/model/state/send/send_session_state.dart';
import 'package:localsend_app/provider/network/send_provider.dart';
import 'package:test/test.dart';

void main() {
  test('records remote upload session id on the local session entry', () {
    const localSessionId = 'local-session';
    const remoteSessionId = 'remote-session';
    final session = SendSessionState(
      sessionId: localSessionId,
      remoteSessionId: null,
      background: true,
      status: SessionStatus.waiting,
      target: _device(),
      files: const {},
      startTime: null,
      endTime: null,
      sendingTasks: const [],
      errorMessage: null,
    );

    final updated = applyRemoteSessionIdForUpload(
      {localSessionId: session},
      localSessionId: localSessionId,
      remoteSessionId: remoteSessionId,
    );

    expect(updated[localSessionId]?.remoteSessionId, remoteSessionId);
    expect(updated.containsKey(remoteSessionId), isFalse);
  });
}

Device _device() {
  return Device(
    signalingId: null,
    ip: '192.168.1.42',
    version: protocolVersion,
    port: 53317,
    https: true,
    fingerprint: 'fp1',
    alias: 'Office PC',
    deviceModel: 'Windows',
    deviceType: DeviceType.desktop,
    download: false,
    discoveryMethods: {const HttpDiscovery(ip: '192.168.1.42')},
  );
}
