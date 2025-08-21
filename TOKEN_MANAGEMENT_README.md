# Token 自动续期系统

这个系统实现了 Flutter ERP 应用的完整 token 管理，包括自动续期、过期检测和全局登出功能。

## 功能特性

### 🔐 自动 Token 续期
- **智能检测**: 每分钟检查 token 状态
- **提前续期**: 在 token 过期前 5 分钟自动续期
- **无缝体验**: 用户无需手动操作，系统自动处理

### ⏰ 过期时间管理
- **精确计时**: 基于服务器返回的 `expiresTime` 计算过期时间
- **双重保护**: 同时管理 access token 和 refresh token 的过期时间
- **自动清理**: token 过期后自动清除所有认证数据

### 🚪 全局登出处理
- **自动跳转**: token 失效时自动跳转到登录页面
- **数据清理**: 清除本地存储的所有认证信息
- **状态同步**: 通过 Riverpod 同步全局认证状态

### 🛡️ 安全机制
- **拦截器保护**: 所有 API 请求都经过认证拦截器
- **错误处理**: 完善的错误处理和日志记录
- **状态管理**: 统一的认证状态管理

## 系统架构

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   TokenManager  │    │ AuthInterceptor  │    │ AuthState      │
│                 │    │                  │    │ Notifier       │
│ • 定时检查      │◄──►│ • 请求拦截       │◄──►│ • 状态管理     │
│ • 自动续期      │    │ • 错误处理       │    │ • 全局登出     │
│ • 过期检测      │    │ • 重试机制       │    │ • 状态同步     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│TokenStorage     │    │     Dio          │    │   UI Pages     │
│                 │    │                  │    │                 │
│ • 安全存储      │    │ • HTTP 客户端    │    │ • 登录页面     │
│ • 过期时间      │    │ • 拦截器链      │    │ • 主页         │
│ • 数据清理      │    │ • 错误处理      │    │ • 状态显示     │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

## 使用方法

### 1. 启动 Token 管理

系统会在用户登录成功后自动启动 token 管理：

```dart
// 在 AuthStateNotifier 中自动启动
void setAuthenticated() {
  state = AuthStatus.authenticated;
  // 启动token管理
  ref.read(tokenManagementControllerProvider).startTokenManagement();
}
```

### 2. 手动刷新 Token

```dart
final controller = ref.read(tokenManagementControllerProvider);
final success = await controller.manualRefreshToken();
```

### 3. 检查 Token 状态

```dart
final controller = ref.read(tokenManagementControllerProvider);
final status = await controller.getTokenStatus();

// 返回状态信息
{
  'hasToken': true,
  'isExpired': false,
  'isExpiringSoon': false,
  'remainingTime': 115, // 分钟
  'status': 'valid'
}
```

### 4. 显示 Token 状态（调试用）

```dart
// 在需要的地方添加这个组件
const TokenStatusWidget()
```

## 配置选项

### Token 检查间隔
```dart
// 在 TokenManager 中修改
static const Duration _checkInterval = Duration(minutes: 1); // 每分钟检查一次
```

### 续期阈值
```dart
// 在 TokenManager 中修改
static const Duration _refreshThreshold = Duration(minutes: 5); // 提前5分钟刷新
```

### Token 过期时间
```dart
// 在 AuthInterceptor 中修改
final accessTokenExpiry = now.add(const Duration(hours: 2)); // access token 2小时
final refreshTokenExpiry = now.add(const Duration(days: 7)); // refresh token 7天
```

## 工作流程

### 登录流程
1. 用户输入凭据
2. 调用登录 API
3. 保存 token 和过期时间
4. 获取用户信息
5. 启动 token 管理
6. 跳转到主页

### Token 续期流程
1. 系统检测到 token 即将过期
2. 调用刷新 token API
3. 保存新的 token 和过期时间
4. 继续正常操作

### 过期处理流程
1. 系统检测到 token 已过期
2. 尝试使用 refresh token 续期
3. 如果续期失败，清除所有认证数据
4. 通知认证状态变更
5. 自动跳转到登录页面

## 错误处理

### 网络错误
- 自动重试机制
- 错误日志记录
- 用户友好的错误提示

### Token 错误
- 自动续期尝试
- 失败后的清理操作
- 状态同步

### 系统错误
- 异常捕获和记录
- 降级处理
- 用户通知

## 调试和监控

### 日志输出
系统提供详细的日志输出，包括：
- Token 检查状态
- 续期操作结果
- 错误详情
- 状态变更

### Token 状态组件
使用 `TokenStatusWidget` 可以实时查看：
- Token 有效性
- 剩余时间
- 过期状态
- 手动刷新功能

## 注意事项

1. **网络环境**: 确保网络环境稳定，避免频繁的续期失败
2. **服务器时间**: 确保客户端和服务器时间同步
3. **错误处理**: 系统会自动处理大部分错误，但建议监控日志
4. **性能影响**: Token 检查间隔不宜过短，避免影响应用性能

## 故障排除

### 常见问题

**Q: Token 续期失败怎么办？**
A: 系统会自动清除认证数据并跳转到登录页面，用户重新登录即可。

**Q: 为什么有时候需要重新登录？**
A: 可能是 refresh token 也过期了，或者网络问题导致续期失败。

**Q: 如何查看 Token 状态？**
A: 使用 `TokenStatusWidget` 组件，或者在日志中查看相关信息。

**Q: 可以手动控制 Token 管理吗？**
A: 可以，通过 `TokenManagementController` 提供的方法进行控制。

## 更新日志

### v1.0.0
- 初始版本
- 基本的 token 管理功能
- 自动续期机制
- 全局登出处理

### 后续计划
- 更智能的续期策略
- 离线 token 管理
- 多设备同步
- 安全增强
