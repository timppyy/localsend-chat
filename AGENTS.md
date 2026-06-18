# AGENTS.md

## Project

This repository is a fork of LocalSend for a LAN chat variant, tentatively named `localsend-chat`.

Primary goal: keep LocalSend's LAN discovery and peer-to-peer file transfer, then add a lightweight Telegram-style chat experience for desktop first.

## Repository

- Local path: `D:\Project\localsend`
- Main remote: `origin git@github.com:timppyy/localsend-chat.git`
- Upstream remote: `upstream git@github.com:localsend/localsend.git`
- Feature branch used for this work: `features/localsend-chat`

## First Version Scope

- Add a Chat tab / entry point.
- Add a chat button beside discovered LAN devices.
- Open a conversation per peer device fingerprint.
- Send text over LocalSend's existing HTTP/HTTPS channel.
- Reuse LocalSend's existing file picker and file transfer flow for chat file messages.
- Persist chat history locally on the current device.
- Support first-contact approval: the first text request prompts the receiver; after approval, the sender fingerprint is trusted with a local chat token, and later text messages are accepted directly.
- Do not add accounts, cloud sync, public relay, NAT traversal, or multi-device history sync in v1.

## Identity Model

- `fingerprint` identifies the peer device. It is the stable trust key.
- `ip` is only the current route/address and may change on the LAN.
- `chatToken` is stored per trusted fingerprint after first approval.
- A trusted device record should keep the last known alias, IP, port, HTTPS flag, token, and timestamps.

## Important Paths

- Chat state and persistence:
  - `app/lib/model/state/chat_state.dart`
  - `app/lib/model/persistence/chat_conversation.dart`
  - `app/lib/model/persistence/chat_message.dart`
  - `app/lib/model/persistence/chat_trusted_device.dart`
  - `app/lib/provider/chat_provider.dart`
  - `app/lib/provider/persistence_provider.dart`
- Chat UI:
  - `app/lib/pages/tabs/chat_tab.dart`
  - `app/lib/pages/tabs/chat_tab_vm.dart`
  - `app/lib/pages/home_page.dart`
  - `app/lib/pages/tabs/send_tab.dart`
  - `app/lib/pages/tabs/send_tab_vm.dart`
  - `app/lib/widget/list_tile/device_list_tile.dart`
- LAN API routes and DTOs:
  - `common/lib/api_route_builder.dart`
  - `common/lib/model/dto/chat_peer_dto.dart`
  - `common/lib/model/dto/chat_request_dto.dart`
  - `common/lib/model/dto/chat_request_response_dto.dart`
  - `common/lib/model/dto/chat_message_dto.dart`
  - `app/lib/provider/network/server/controller/chat_controller.dart`
  - `app/lib/provider/network/server/server_provider.dart`
- File receive integration:
  - `app/lib/provider/network/server/controller/receive_controller.dart`
- Tests:
  - `app/test/unit/provider/chat_provider_test.dart`
  - `app/test/unit/provider/chat_persistence_test.dart`
  - `app/test/unit/util/api_route_builder_test.dart`

## Development Commands

Use Flutter `3.38.10` as specified by `.fvmrc`.

From `common/`:

```powershell
flutter pub get
dart run build_runner build -d
```

From `app/`:

```powershell
flutter pub get
flutter pub run slang
dart run build_runner build -d
flutter test test\unit\provider\chat_persistence_test.dart test\unit\provider\chat_provider_test.dart test\unit\util\api_route_builder_test.dart
flutter analyze lib test\unit\provider\chat_persistence_test.dart test\unit\provider\chat_provider_test.dart test\unit\util\api_route_builder_test.dart
flutter build windows
```

## Current Validation Notes

- Chat-related tests have passed with Flutter 3.38.10.
- Chat-related scoped analyze has passed.
- Full `flutter analyze` may include unrelated `rust_builder/cargokit/build_tool` dependency noise if that subpackage has not resolved its own dependencies.
- Windows build reached Flutter's Windows build flow and detected Visual Studio, but this machine hit a Flutter/Dart file decode issue while reading `app/windows/flutter/CMakeLists.txt`. Treat that as a local build-environment problem to resolve before claiming a final release exe.

## Git Hygiene

- Do not commit local SDK/cache workaround directories such as `.codex-flutter-*`, `.codex-pub-cache`, or preview executables.
- Do not commit temporary dependency changes made only to work around GitHub TLS failures.
- Avoid broad generated-file churn. Commit generated files only when the corresponding source changes require them.
- Keep `origin` as the fork target and avoid pushing to `upstream`.
