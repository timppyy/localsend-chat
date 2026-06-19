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

If `flutter` is not on `PATH`, use a repo-local ignored SDK:

```powershell
git clone --depth 1 --branch 3.38.10 https://github.com/flutter/flutter.git .fvm\flutter_sdk
```

For sandboxed or non-admin agent runs, keep SDK, Pub, and Dart tool state inside the repository's ignored `.fvm/` directory:

```powershell
$env:GIT_CONFIG_COUNT='1'
$env:GIT_CONFIG_KEY_0='safe.directory'
$env:GIT_CONFIG_VALUE_0='D:/Project/localsend-chat/.fvm/flutter_sdk'
$env:PUB_CACHE='D:\Project\localsend-chat\.fvm\pub-cache'
$env:APPDATA='D:\Project\localsend-chat\.fvm\appdata\Roaming'
$env:LOCALAPPDATA='D:\Project\localsend-chat\.fvm\appdata\Local'
$env:DART_SUPPRESS_ANALYTICS='true'
```

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

Use `D:\Project\localsend-chat\.fvm\flutter_sdk\bin\flutter.bat` and `D:\Project\localsend-chat\.fvm\flutter_sdk\bin\dart.bat` in the commands above when using the repo-local SDK.

## Agent Build Runbook

This is the verified flow from the final `features/localsend-chat` build pass:

1. Confirm branch and worktree:
   ```powershell
   git status --short --branch
   ```
2. Install dependencies:
   ```powershell
   cd common
   ..\.fvm\flutter_sdk\bin\flutter.bat pub get
   cd ..\app
   ..\.fvm\flutter_sdk\bin\flutter.bat pub get
   ```
3. Generate code:
   ```powershell
   cd ..\common
   ..\.fvm\flutter_sdk\bin\dart.bat run build_runner build -d
   cd ..\app
   ..\.fvm\flutter_sdk\bin\dart.bat run slang
   ..\.fvm\flutter_sdk\bin\dart.bat run build_runner build -d
   ```
4. Run targeted chat verification:
   ```powershell
   ..\.fvm\flutter_sdk\bin\flutter.bat test test/unit/util/api_route_builder_test.dart test/unit/provider/chat_persistence_test.dart test/unit/provider/chat_provider_test.dart
   ..\.fvm\flutter_sdk\bin\flutter.bat analyze lib test/unit/provider/chat_persistence_test.dart test/unit/provider/chat_provider_test.dart test/unit/util/api_route_builder_test.dart
   ```
5. Run broader unit coverage:
   ```powershell
   ..\.fvm\flutter_sdk\bin\flutter.bat test test/unit
   ```
6. Build Windows:
   ```powershell
   ..\.fvm\flutter_sdk\bin\flutter.bat build windows
   ```
   Expected output:
   ```text
   Built build\windows\x64\runner\Release\localsend_app.exe
   ```

Windows-specific notes:

- Flutter plugin builds require Windows Developer Mode or equivalent symlink privilege.
- Visual Studio 2026 / MSVC v180 requires `_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS` for plugins that still include `<experimental/coroutine>`.
- C++/WinRT users such as `gal_plugin` and `winrt_ext.cpp` need `runtimeobject.lib`.
- `localsend_msix_helper.msix` is optional in this fork; CMake must not unconditionally install it when the file is absent.
- Rust-backed plugins (`rhttp`, `rust_lib_localsend_app`) may need network access to `crates.io` on the first Windows build.
- If `Couldn't resolve the package 'build_tool'` appears in `*_cargokit.vcxproj`, run `dart pub get` in the generated runner dirs under `app/build/windows/x64/plugins/*/cargokit_build/tool/`, then retry the build.

Chat debugging and UX notes:

- A chat bubble that shows `FormatException: Unexpected character ... Not found` means the sender tried to parse a plain-text HTTP error as JSON. The common cause is that the target device does not expose the chat route, for example an older/non-chat LocalSend build or a mismatched chat endpoint.
- Keep transport/parser errors out of persisted chat text. Convert non-JSON HTTP responses into a short user-facing error such as `Chat is not available on this device.` before saving `ChatMessage.errorMessage`.
- Message text should use `SelectableText` so users can select and copy partial text with the platform selection toolbar.
- Each chat message bubble should keep a compact actions menu for whole-message copy and local message deletion.
- Deleting a message is local history cleanup: remove it from persisted chat messages, then refresh the conversation summary from the latest remaining message or remove the conversation if no messages remain.

## Current Validation Notes

- Verified on this machine with Flutter 3.38.10 / Dart 3.10.9 and Visual Studio 2026.
- `flutter test test/unit` passed: 73 tests.
- Chat-related scoped analyze passed with no issues.
- `flutter build windows` succeeded and produced `app/build/windows/x64/runner/Release/localsend_app.exe`.
- Full `flutter analyze` may include unrelated `rust_builder/cargokit/build_tool` dependency noise if that subpackage has not resolved its own dependencies.

## Git Hygiene

- Do not commit local SDK/cache workaround directories such as `.fvm/flutter_sdk`, `.fvm/pub-cache`, `.fvm/appdata`, `.codex-flutter-*`, `.codex-pub-cache`, or preview executables.
- Do not commit temporary dependency changes made only to work around GitHub TLS failures.
- Avoid broad generated-file churn. `slang` and `build_runner` may refresh many generated files because of tool-version formatting changes; commit generated files only when the corresponding source changes require them.
- Keep `origin` as the fork target and avoid pushing to `upstream`.
