# localsend-chat Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first desktop-focused LAN chat version of LocalSend with trusted text chat, local history, and file sending from the chat page.

**Architecture:** Add a small Chat subsystem beside the existing Send/Receive subsystems. Text chat uses new HTTP v2 chat endpoints with `fingerprint + chatToken` trust, while file messages continue to use `sendProvider.startSession()`. Chat state and trust are stored locally through `PersistenceService`, following the existing favorites/history style.

**Tech Stack:** Flutter/Dart, Refena providers, dart_mappable DTOs/models, SharedPreferences persistence, LocalSend `SimpleServer`, existing Rust HTTP client where possible and Dart `HttpClient` fallback for new chat endpoints.

---

## File Structure

- Modify: `common/lib/api_route_builder.dart`
  - Add `chatRequest` and `chatMessage` v2 routes.
- Create: `common/lib/model/dto/chat_peer_dto.dart`
- Create: `common/lib/model/dto/chat_request_dto.dart`
- Create: `common/lib/model/dto/chat_request_response_dto.dart`
- Create: `common/lib/model/dto/chat_message_dto.dart`
  - Add dart_mappable DTOs used by both sender and receiver.
- Create: `app/lib/model/persistence/chat_trusted_device.dart`
- Create: `app/lib/model/persistence/chat_conversation.dart`
- Create: `app/lib/model/persistence/chat_message.dart`
  - Add local persistence models.
- Modify: `app/lib/provider/persistence_provider.dart`
  - Add chat storage keys and get/set methods.
- Create: `app/lib/provider/chat_provider.dart`
  - Own conversations, messages, trust records, text send actions, and file-message records.
- Create: `app/lib/provider/network/server/controller/chat_controller.dart`
  - Install and handle chat HTTP endpoints.
- Modify: `app/lib/provider/network/server/server_provider.dart`
  - Instantiate and install `ChatController`.
- Modify: `app/lib/pages/home_page.dart`
  - Add `HomeTab.chat` and page view child.
- Create: `app/lib/pages/tabs/chat_tab.dart`
- Create: `app/lib/pages/tabs/chat_tab_vm.dart`
  - Implement Telegram-style desktop chat UI.
- Modify: `app/assets/i18n/strings_en.i18n.json`
- Modify: `app/assets/i18n/strings_zh_CN.i18n.json`
  - Add minimal strings for Chat tab and authorization dialog.
- Test: `app/test/unit/provider/chat_provider_test.dart`
- Test: `app/test/unit/util/api_route_builder_test.dart`
- Test: `app/test/unit/provider/chat_persistence_test.dart`

## Task 1: API Routes And DTOs

**Files:**
- Modify: `common/lib/api_route_builder.dart`
- Create: `common/lib/model/dto/chat_peer_dto.dart`
- Create: `common/lib/model/dto/chat_request_dto.dart`
- Create: `common/lib/model/dto/chat_request_response_dto.dart`
- Create: `common/lib/model/dto/chat_message_dto.dart`
- Test: `app/test/unit/util/api_route_builder_test.dart`

- [ ] **Step 1: Write the failing API route test**

Add to `app/test/unit/util/api_route_builder_test.dart`:

```dart
test('chat routes are v2 only', () {
  expect(ApiRoute.chatRequest.v1, '/api/localsend/v1/chat/request');
  expect(ApiRoute.chatRequest.v2, '/api/localsend/v2/chat/request');
  expect(ApiRoute.chatMessage.v1, '/api/localsend/v1/chat/message');
  expect(ApiRoute.chatMessage.v2, '/api/localsend/v2/chat/message');
});
```

- [ ] **Step 2: Run the route test and verify RED**

Run:

```powershell
flutter test test/unit/util/api_route_builder_test.dart
```

Expected: FAIL because `ApiRoute.chatRequest` and `ApiRoute.chatMessage` do not exist.

- [ ] **Step 3: Add routes**

Add enum values before the trailing semicolon in `common/lib/api_route_builder.dart`:

```dart
chatRequest('chat/request'),
chatMessage('chat/message'),
```

- [ ] **Step 4: Add DTOs**

Create dart_mappable DTO files in `common/lib/model/dto/`:

```dart
@MappableClass()
class ChatPeerDto with ChatPeerDtoMappable {
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
}
```

Create `chat_request_dto.dart`:

```dart
@MappableClass()
class ChatRequestDto with ChatRequestDtoMappable {
  final ChatPeerDto sender;
  final String messageId;
  final String text;
  final DateTime timestamp;

  const ChatRequestDto({
    required this.sender,
    required this.messageId,
    required this.text,
    required this.timestamp,
  });

  static const fromJson = ChatRequestDtoMapper.fromJson;
}
```

Create `chat_request_response_dto.dart`:

```dart
@MappableClass()
class ChatRequestResponseDto with ChatRequestResponseDtoMappable {
  final String chatToken;

  const ChatRequestResponseDto({
    required this.chatToken,
  });

  static const fromJson = ChatRequestResponseDtoMapper.fromJson;
}
```

Create `chat_message_dto.dart`:

```dart
@MappableClass()
class ChatMessageDto with ChatMessageDtoMappable {
  final ChatPeerDto sender;
  final String chatToken;
  final String messageId;
  final String text;
  final DateTime timestamp;

  const ChatMessageDto({
    required this.sender,
    required this.chatToken,
    required this.messageId,
    required this.text,
    required this.timestamp,
  });

  static const fromJson = ChatMessageDtoMapper.fromJson;
}
```

- [ ] **Step 5: Generate mappers**

Run:

```powershell
dart run build_runner build -d
```

from `common/`.

- [ ] **Step 6: Verify GREEN**

Run:

```powershell
flutter test test/unit/util/api_route_builder_test.dart
```

Expected: PASS.

## Task 2: Chat Persistence Models And Storage

**Files:**
- Create: `app/lib/model/persistence/chat_trusted_device.dart`
- Create: `app/lib/model/persistence/chat_conversation.dart`
- Create: `app/lib/model/persistence/chat_message.dart`
- Modify: `app/lib/provider/persistence_provider.dart`
- Modify: `app/test/mocks.dart`
- Test: `app/test/unit/provider/chat_persistence_test.dart`

- [ ] **Step 1: Write failing persistence tests**

Create `app/test/unit/provider/chat_persistence_test.dart` with tests that instantiate `ReduxNotifier.test(redux: ChatService(persistenceService))` and verify:

```dart
test('trusts a device and persists it', () async {
  when(persistenceService.getChatTrustedDevices()).thenReturn([]);
  when(persistenceService.getChatConversations()).thenReturn([]);
  when(persistenceService.getChatMessages()).thenReturn([]);

  final service = ReduxNotifier.test(redux: ChatService(persistenceService));
  final trusted = _trustedDevice('fp1', token: 'token1');

  await service.dispatchAsync(TrustChatDeviceAction(trusted));

  expect(service.state.trustedDevices, [trusted]);
  verify(persistenceService.setChatTrustedDevices([trusted]));
});
```

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/unit/provider/chat_persistence_test.dart
```

Expected: FAIL because chat models/provider/storage do not exist.

- [ ] **Step 3: Add persistence models**

Use `@MappableClass()` and generated mapper parts for:

```dart
class ChatTrustedDevice {
  final String fingerprint;
  final String alias;
  final String token;
  final String? lastIp;
  final int? lastPort;
  final bool? https;
  final DateTime trustedAt;
  final DateTime updatedAt;
}

class ChatConversation {
  final String peerFingerprint;
  final String alias;
  final String? lastIp;
  final int? lastPort;
  final bool? https;
  final String? lastMessage;
  final DateTime updatedAt;
}

class ChatMessage {
  final String id;
  final String peerFingerprint;
  final ChatMessageDirection direction;
  final ChatMessageKind kind;
  final ChatMessageStatus status;
  final String? text;
  final String? fileName;
  final int? fileSize;
  final String? filePath;
  final String? errorMessage;
  final DateTime timestamp;
}
```

Use enums `ChatMessageDirection`, `ChatMessageKind`, `ChatMessageStatus` in `chat_message.dart`.

- [ ] **Step 4: Add storage methods**

In `app/lib/provider/persistence_provider.dart`, add keys:

```dart
const _chatTrustedDevices = 'ls_chat_trusted_devices';
const _chatConversations = 'ls_chat_conversations';
const _chatMessages = 'ls_chat_messages';
```

Add get/set methods using the same string-list JSON pattern as receive history.

- [ ] **Step 5: Generate app mappers and mocks**

Run from `app/`:

```powershell
dart run build_runner build -d
```

- [ ] **Step 6: Verify GREEN**

Run:

```powershell
flutter test test/unit/provider/chat_persistence_test.dart
```

Expected: PASS.

## Task 3: Chat Provider Text Sending Logic

**Files:**
- Create: `app/lib/model/state/chat_state.dart`
- Create: `app/lib/provider/chat_provider.dart`
- Test: `app/test/unit/provider/chat_provider_test.dart`

- [ ] **Step 1: Write failing provider tests**

Create tests for:

- offline device creates failed outgoing message.
- trusted device sends through `/chat/message`.
- missing token sends through `/chat/request` and persists returned token.
- declined request marks message declined.

Use injected function parameters in `ChatService` for HTTP posting so tests can use real provider logic without real network.

- [ ] **Step 2: Run tests and verify RED**

Run:

```powershell
flutter test test/unit/provider/chat_provider_test.dart
```

Expected: FAIL because `ChatService` does not exist.

- [ ] **Step 3: Implement chat state and provider**

`ChatState` contains:

```dart
final List<ChatTrustedDevice> trustedDevices;
final List<ChatConversation> conversations;
final List<ChatMessage> messages;
final String? selectedFingerprint;
```

`ChatService` actions include:

- `SelectConversationAction`
- `TrustChatDeviceAction`
- `AddIncomingChatMessageAction`
- `SendTextMessageAction`
- `AddOutgoingFileMessageAction`

- [ ] **Step 4: Verify GREEN**

Run:

```powershell
flutter test test/unit/provider/chat_provider_test.dart
```

Expected: PASS.

## Task 4: Server Chat Controller

**Files:**
- Create: `app/lib/provider/network/server/controller/chat_controller.dart`
- Modify: `app/lib/provider/network/server/server_provider.dart`
- Test: unit tests if controller is factored into testable handler methods.

- [ ] **Step 1: Write failing handler tests**

Add tests for pure handler methods:

- unknown token rejects `/chat/message`.
- known token stores incoming message.
- first request delegates to authorization callback.

- [ ] **Step 2: Run tests and verify RED**

Run targeted controller tests.

- [ ] **Step 3: Implement `ChatController`**

Install routes:

```dart
router.post(ApiRoute.chatRequest.v2, (request) async {
  return await _chatRequestHandler(request: request, alias: alias, port: port, https: https, fingerprint: fingerprint);
});

router.post(ApiRoute.chatMessage.v2, (request) async {
  return await _chatMessageHandler(request: request, fingerprint: fingerprint);
});
```

Use `request.readAsString()`, DTO parsing, `request.respondJson()`, and `chatProvider` actions.

- [ ] **Step 4: Wire into server**

Add `_chatController` to `ServerService` and call `installRoutes()` after receive/send route installation.

- [ ] **Step 5: Verify GREEN**

Run controller tests and a format/analyze pass.

## Task 5: Chat UI And Navigation

**Files:**
- Modify: `app/lib/pages/home_page.dart`
- Create: `app/lib/pages/tabs/chat_tab.dart`
- Create: `app/lib/pages/tabs/chat_tab_vm.dart`
- Modify: `app/assets/i18n/strings_en.i18n.json`
- Modify: `app/assets/i18n/strings_zh_CN.i18n.json`

- [ ] **Step 1: Write failing widget test**

Add a widget test that renders `ChatTab` with a seeded `ChatState` and expects:

- conversation alias visible.
- message text visible.
- input field visible.

- [ ] **Step 2: Run test and verify RED**

Run:

```powershell
flutter test test/widget/chat_tab_test.dart
```

Expected: FAIL because `ChatTab` does not exist.

- [ ] **Step 3: Implement `HomeTab.chat`**

Add `chat(Icons.chat)` to `HomeTab`, add label mapping, and add `SafeArea(child: ChatTab())` to the `PageView`.

- [ ] **Step 4: Implement `ChatTab`**

Use a desktop-first two-pane layout:

```dart
Row(
  children: [
    SizedBox(width: 320, child: _ConversationList(vm: vm)),
    VerticalDivider(width: 1),
    Expanded(child: _ChatDetail(vm: vm)),
  ],
)
```

Use compact mobile fallback by stacking conversation list/detail.

- [ ] **Step 5: Implement text and file actions**

Text send calls `SendTextMessageAction`.

Attachment button uses existing file picker utilities and then calls:

```dart
ref.notifier(sendProvider).startSession(target: device, files: files, background: false);
ref.redux(chatProvider).dispatch(
  AddOutgoingFileMessageAction(
    peerFingerprint: device.fingerprint,
    fileName: files.first.name,
    fileSize: files.first.size,
    filePath: files.first.path,
  ),
);
```

- [ ] **Step 6: Generate translations**

Run from `app/`:

```powershell
dart run slang
```

- [ ] **Step 7: Verify GREEN**

Run:

```powershell
flutter test test/widget/chat_tab_test.dart
```

Expected: PASS.

## Task 6: Full Verification

**Files:**
- All changed files.

- [ ] **Step 1: Run generated code check**

Run from `common/`:

```powershell
dart run build_runner build -d
```

Run from `app/`:

```powershell
dart run build_runner build -d
```

- [ ] **Step 2: Run targeted tests**

Run:

```powershell
flutter test test/unit/util/api_route_builder_test.dart
flutter test test/unit/provider/chat_persistence_test.dart
flutter test test/unit/provider/chat_provider_test.dart
flutter test test/widget/chat_tab_test.dart
```

- [ ] **Step 3: Run analyzer**

Run from `app/`:

```powershell
flutter analyze
```

- [ ] **Step 4: Manual smoke check**

Run the app on desktop and verify:

- Chat tab appears.
- Selecting a nearby device opens a conversation.
- First text request triggers confirmation on receiver.
- Second text request is accepted silently.
- Attachment file send opens the existing LocalSend send/progress flow.

- [ ] **Step 5: Commit implementation**

Commit with:

```powershell
git add common app docs
git commit -m "feat: add LAN chat tab"
```
