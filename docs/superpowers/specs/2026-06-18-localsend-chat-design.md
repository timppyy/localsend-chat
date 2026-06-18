# localsend-chat 第一版设计

## 目标

基于 LocalSend 增加一个局域网聊天体验，暂名 `localsend-chat`。第一版保留 LocalSend 原有设备发现、点对点文件传输和接收确认能力，同时新增 Telegram 式桌面聊天入口：按设备建立会话，支持文本消息和聊天内发送文件，本地保存聊天历史，不依赖公网服务器。

## 第一版范围

包含：

- 新增 Chat tab。
- 局域网设备列表和聊天会话列表都可以进入聊天窗口。
- 会话按设备 `fingerprint` 归档。
- 首次文本聊天请求需要接收端确认。
- 接收端同意后保存 `fingerprint + chatToken` 到聊天信任列表。
- 后续同一设备发送文本消息时直接入库，不再弹窗。
- 文本消息使用新增轻量 HTTP chat API。
- 聊天页附件按钮复用 LocalSend 现有文件发送流程。
- 聊天记录保存在当前设备本地。

不包含：

- 账号体系。
- 云端服务。
- 公网穿透。
- 多端历史同步。
- 已读回执。
- 输入中状态。
- 实时长连接或 WebSocket。
- 移动端专门适配。

## 现有代码基础

LocalSend 已有几个可复用基础：

- `Device.fingerprint` 是设备身份字段，来源于本机 security context 的证书 SHA-256。
- `nearbyDevicesProvider` 持有局域网发现到的设备，当前 HTTP 发送依赖设备的 `ip/port/https`。
- `sendProvider.startSession()` 已经负责 prepare-upload/upload 文件发送流程。
- `ReceiveController` 安装现有接收端 HTTP API，包括 info/register/prepare-upload/upload/cancel/show。
- `PersistenceService` 基于 SharedPreferences 保存 favorites、接收历史和设置。

聊天功能应复用设备发现和文件发送能力，但不要把聊天信任混入 favorites。收藏设备是用户整理设备列表；聊天信任是“允许对方免确认发送文本”的权限。

## 身份和信任模型

会话主键使用 `fingerprint`：

- `fingerprint`：标识对方 LocalSend 安装，用于归档会话、查询信任记录。
- `ip/port/https`：标识当前网络连接位置，只作为发送时的路由信息，会随设备发现刷新。
- `alias`：显示名，可根据最新发现结果更新。
- `chatToken`：聊天授权令牌，首次同意后生成，后续文本消息必须携带。

信任记录本地保存：

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
```

安全边界：

- 第一版不把 fingerprint 当作强认证凭据。
- 后续文本必须同时匹配 `fingerprint` 和 `chatToken`。
- 如果用户清空设置或重装 LocalSend，fingerprint 会变化，会被视为新设备，需要重新授权。
- 如果对方知道旧 token，第一版没有撤销 UI；可在后续版本增加“移除聊天信任”。

## 本地数据模型

新增聊天会话：

```dart
class ChatConversation {
  final String peerFingerprint;
  final String alias;
  final String? lastIp;
  final int? lastPort;
  final bool? https;
  final String? lastMessage;
  final DateTime updatedAt;
}
```

新增聊天消息：

```dart
enum ChatMessageDirection {
  incoming,
  outgoing,
}

enum ChatMessageKind {
  text,
  file,
}

enum ChatMessageStatus {
  sending,
  sent,
  received,
  failed,
  declined,
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

持久化：

- `PersistenceService` 新增 `getChatTrustedDevices/setChatTrustedDevices`。
- `PersistenceService` 新增 `getChatConversations/setChatConversations`。
- `PersistenceService` 新增 `getChatMessages/setChatMessages`。
- 第一版使用 SharedPreferences 的 string list JSON，沿用现有 receive history/favorites 风格。
- 为避免无限膨胀，第一版每个会话最多保存最近 500 条消息。

## HTTP API

新增路由枚举：

- `ApiRoute.chatRequest` -> `/api/localsend/v2/chat/request`
- `ApiRoute.chatMessage` -> `/api/localsend/v2/chat/message`

新增 DTO：

```dart
class ChatPeerDto {
  final String alias;
  final String version;
  final String? deviceModel;
  final DeviceType deviceType;
  final String fingerprint;
  final int port;
  final ProtocolType protocol;
}

class ChatRequestDto {
  final ChatPeerDto sender;
  final String messageId;
  final String text;
  final DateTime timestamp;
}

class ChatRequestResponseDto {
  final String chatToken;
}

class ChatMessageDto {
  final ChatPeerDto sender;
  final String chatToken;
  final String messageId;
  final String text;
  final DateTime timestamp;
}
```

首次请求流程：

```text
发送端 POST /chat/request
接收端检查 sender.fingerprint 是否已信任
  已信任：保存文本，返回现有 token
  未信任：弹窗确认
    同意：生成 chatToken，保存信任，保存文本，返回 token
    拒绝：返回 403
发送端收到 token 后保存对方信任信息并将消息标记 sent
```

后续文本流程：

```text
发送端 POST /chat/message，携带 fingerprint + chatToken
接收端校验信任记录
  成功：保存文本，返回 200
  失败：返回 401 或 403
发送端遇到 401/403 时可退回 /chat/request 流程
```

## 发送文本

新增 `chatProvider` 管理聊天状态和发送动作。

发送文本时：

1. 按 `peerFingerprint` 从 `nearbyDevicesProvider.allDevices` 找在线设备。
2. 找不到在线设备时，新增 outgoing 消息并标记 `failed`，错误为对方离线。
3. 找到设备后，先本地新增 outgoing 消息，状态 `sending`。
4. 如果本地有对该 fingerprint 的 token，调用 `/chat/message`。
5. 如果没有 token 或 token 被拒绝，调用 `/chat/request`。
6. 成功后更新消息状态为 `sent`，保存 token。
7. 失败后更新状态为 `failed` 或 `declined`。

## 接收文本

新增 `ChatController`，由 `serverProvider` 安装路由。

接收文本时：

1. 从请求体解析 sender、messageId、text。
2. 如果 sender fingerprint 等于本机 fingerprint，返回 412，避免自发自收。
3. `/chat/message` 必须校验 token。
4. `/chat/request` 在无信任记录时弹窗确认。
5. 同意或校验通过后，将 sender 注册/更新到 nearby device 状态，并写入聊天历史。
6. 如果当前正在 Chat tab 中打开该会话，消息流实时刷新。

## 文件消息

聊天内文件发送不新增文件协议，复用现有 `sendProvider.startSession()`：

1. 用户在聊天页点附件按钮。
2. 选择文件后，使用当前会话 fingerprint 查找在线 `Device`。
3. 调用 `sendProvider.startSession(target: device, files: files, background: false)`。
4. 同时写入一条 outgoing file 消息，包含文件名、大小和初始状态。
5. 第一版文件消息状态可以只记录“已发起/失败”，详细进度仍显示在现有发送/进度页面。

接收文件仍走现有 LocalSend 接收确认流程，不因聊天信任而自动接收文件。

## UI 设计

新增 `HomeTab.chat`，桌面优先。

Chat tab 布局：

```text
左侧
  搜索/标题
  会话列表
  附近可聊天设备入口

右侧
  顶部：设备名、在线状态、当前 IP
  中部：消息流，左右气泡区分 incoming/outgoing
  底部：附件按钮、文本输入框、发送按钮
```

会话列表排序：

- 有消息历史的会话按 `updatedAt` 倒序。
- 附近设备没有历史时显示为“可发起聊天”。

空状态：

- 无会话时提示选择附近设备开始聊天。
- 选中离线会话时输入框可编辑，但发送后消息标记 failed；第一版不做离线队列。

## 错误处理

- 对方离线：消息 `failed`，显示错误，可后续增加重试按钮。
- 对方拒绝首次聊天：消息 `declined`。
- token 失效：自动退回首次请求；若仍失败，标记 `failed`。
- 请求体非法：接收端返回 400。
- sender 是自己：接收端返回 412。
- 文件发送错误：沿用现有发送页/进度页错误。

## 测试范围

单元测试：

- chat persistence add/update/remove。
- chat provider 发送文本成功。
- 无 token 时走 chat request，成功后保存 token。
- token 失败时退回 chat request。
- 离线设备发送失败。
- 接收端 token 校验。

轻量 UI/widget 测试：

- Chat tab 渲染会话列表和消息流。
- 文本输入发送按钮触发发送动作。

手动验证：

- 两台桌面端在同一局域网发现彼此。
- A 首次给 B 发文本，B 弹确认。
- B 同意后，B 收到第一条消息。
- A 再发文本，B 不再弹窗，消息直接进入会话。
- 聊天页附件发送文件，接收端仍出现现有文件确认/进度流程。

## 验收标准

- 原有 Receive/Send/Settings tab 不回退。
- 新增 Chat tab 可进入并显示会话布局。
- 从附近设备可创建或打开聊天会话。
- 首次文本请求需要接收端确认。
- 同意后后续文本直接接收。
- 聊天历史重启后仍可见。
- 聊天内文件发送复用原 LocalSend 文件传输。
- 不引入公网服务器依赖。
