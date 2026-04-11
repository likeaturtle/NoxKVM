# ICE 收集完成阶段卡住问题排查指南

## 问题描述

本地编译的应用在运行时卡在 "ICE 收集完成"（ICE Gathering completed）阶段，WebRTC 连接无法建立。

## 问题原因分析

根据代码分析，ICE 收集完成后需要完成以下步骤才能建立连接：

1. **ICE 候选交换** - 客户端和设备需要互相交换 ICE 候选地址
2. **SDP 交换** - 完成 Session Description Protocol 的交换
3. **信令通道** - WebSocket 连接必须保持正常

卡住的可能原因：

### 1. 信令模式问题

代码中存在两种信令模式：

- **新信令模式**（New Signaling）：ICE 收集过程中就发送 offer
- **旧信令模式**（Legacy Signaling）：等待 ICE 收集完成后才发送 offer

关键代码位置：`ui/src/routes/devices.$id.tsx`

```typescript
const isNewSignalingEnabled = isLegacySignalingEnabled.current === false;
if (isNewSignalingEnabled) {
  sendWebRTCSignal("offer", { sd: sd });
} else {
  console.log("Legacy signaling. Waiting for ICE Gathering to complete...");
}
```

### 2. WebSocket 连接问题

ICE 候选通过 WebSocket 传输，如果 WebSocket 连接断开或阻塞，候选无法交换。

### 3. 网络/防火墙问题

- 本地网络阻止了 WebRTC 所需的 UDP 端口
- NAT 穿透失败
- 缺少 STUN/TURN 服务器配置

### 4. 编译版本不匹配

本地编译的二进制文件可能与前端代码版本不一致，导致信令协议不兼容。

---

## 诊断步骤

### 步骤 1：检查浏览器控制台日志

打开浏览器开发者工具（F12），查看 Console 标签页：

```javascript
// 正常流程应该看到：
"ICE Gathering Started"
"ICE Gathering completed"
// 然后应该有：
"Successfully got Remote Session Description. Setting."
```

如果只看到 "ICE Gathering completed" 而没有后续消息，说明信令流程卡住了。

### 步骤 2：检查 WebSocket 连接

在浏览器控制台的 Network 标签页中：

1. 筛选 WS（WebSocket）连接
2. 找到与设备的 WebSocket 连接
3. 检查连接状态是否为 "101 Switching Protocols"
4. 查看 Messages 标签，确认是否有消息交换

应该能看到类似这样的消息：
```json
{"type": "offer", "data": {"sd": "..."}}
{"type": "new-ice-candidate", "data": {...}}
{"type": "answer", "data": {"sd": "..."}}
```

### 步骤 3：检查设备端日志

通过 SSH 连接到设备查看日志：

```bash
ssh root@<设备IP>
tail -f /userdata/jetkvm/last.log
```

查找以下关键日志：

```
"new session request received"           # 收到连接请求
"WebRTC peerConnection has a new ICE candidate"  # 收到 ICE 候选
"ICE Connection State has changed"       # ICE 状态变化
```

### 步骤 4：检查信令模式

在浏览器控制台中执行：

```javascript
// 检查是否启用了旧信令模式
console.log(isLegacySignalingEnabled.current);
```

- `true` = 使用旧信令（等待 ICE 完成后发送 HTTP 请求）
- `false` = 使用新信令（通过 WebSocket 立即发送）

---

## 解决方案

### 方案 1：清理并重新编译（推荐）

版本不匹配是最常见的原因：

```bash
cd ~/NoxKVM

# 1. 完全清理前端
cd ui
rm -rf node_modules/
rm -rf ../static/
npm ci
cd ..

# 2. 清理 Go 缓存
go clean -cache
go clean -modcache
go mod tidy

# 3. 重新编译前端
make frontend

# 4. 重新编译后端
make build_dev

# 5. 部署到设备
./dev_deploy.sh -r <设备IP>
```

### 方案 2：检查 WebSocket 连接

确保前端能正确连接到设备：

```bash
# 测试 WebSocket 连接
curl -i -N -H "Connection: Upgrade" \
       -H "Upgrade: websocket" \
       -H "Sec-WebSocket-Version: 13" \
       -H "Sec-WebSocket-Key: dGhlIHNhbXBsZSBub25jZQ==" \
       http://<设备IP>/ws
```

应该返回 `101 Switching Protocols`。

### 方案 3：禁用 Legacy 信令模式

如果你在使用本地设备模式（非云模式），确保不使用 legacy 模式。

检查前端代码中的判断逻辑：

```typescript
// ui/src/routes/devices.$id.tsx
// 确保 isOnDevice 为 true 时不使用 legacy 模式
```

### 方案 4：检查网络配置

#### 检查 mDNS 设置

查看配置文件 `/userdata/kvm_config.json`：

```json
{
  "network": {
    "mdns_mode": "query_only"  // 或 "disabled"
  }
}
```

如果 mDNS 有问题，可以禁用：

```bash
# SSH 到设备
ssh root@<设备IP>
echo '{"network":{"mdns_mode":"disabled"}}' > /userdata/kvm_config.json
systemctl restart jetkvm
```

#### 检查防火墙

确保以下端口未被阻止：

- **UDP 10000-65535** - WebRTC 媒体流
- **TCP 80/443** - HTTP/HTTPS 和 WebSocket
- **UDP 5353** - mDNS（如果使用）

### 方案 5：添加 STUN 服务器

如果设备在 NAT 后面，可能需要 STUN 服务器。

编辑前端代码，添加 ICE 服务器配置：

```typescript
// ui/src/routes/devices.$id.tsx
pc = new RTCPeerConnection({
  iceServers: [
    { urls: 'stun:stun.l.google.com:19302' },
    { urls: 'stun:stun1.l.google.com:19302' }
  ]
});
```

### 方案 6：启用详细日志

启用详细的 WebRTC 日志来诊断问题：

#### 前端日志

在浏览器控制台中设置：

```javascript
localStorage.setItem('debug', '*');
```

#### 后端日志

部署时启用追踪：

```bash
./dev_deploy.sh -r <设备IP> --log-trace "webrtc,websocket,native"
```

---

## 快速修复脚本

创建一个快速修复脚本来重新部署：

```bash
#!/bin/bash
# fix_ice_issue.sh

DEVICE_IP=$1

if [ -z "$DEVICE_IP" ]; then
    echo "用法: sudo $0 <设备IP>"
    exit 1
fi

echo "正在修复 ICE 连接问题..."

# 重新编译
echo "[1/4] 重新编译前端..."
make frontend

echo "[2/4] 重新编译后端..."
make build_dev SKIP_NATIVE_IF_EXISTS=1

# 部署
echo "[3/4] 部署到设备..."
ssh root@$DEVICE_IP "killall jetkvm_app_debug || true"
scp bin/jetkvm_app root@$DEVICE_IP:/userdata/jetkvm/bin/jetkvm_app_debug
ssh root@$DEVICE_IP "chmod +x /userdata/jetkvm/bin/jetkvm_app_debug"

# 重启服务
echo "[4/4] 重启设备服务..."
ssh root@$DEVICE_IP "systemctl restart jetkvm"

echo "完成！请在浏览器中刷新页面重试。"
```

使用方法：

```bash
chmod +x fix_ice_issue.sh
./fix_ice_issue.sh 192.168.1.100
```

---

## 验证修复

修复后，按以下步骤验证：

1. **清除浏览器缓存**
   ```
   Ctrl+Shift+Delete（清除缓存和 Cookie）
   ```

2. **硬刷新页面**
   ```
   Ctrl+Shift+R 或 Ctrl+F5
   ```

3. **检查连接状态**
   
   应该看到以下流程：
   - ✅ Connecting to device...
   - ✅ Creating peer connection...
   - ✅ Gathering ICE candidates...
   - ✅ ICE Gathering completed
   - ✅ Setting remote session description
   - ✅ Connected!

4. **检查 WebRTC 状态**
   
   在浏览器地址栏输入：
   ```
   chrome://webrtc-internals  (Chrome)
   about:webrtc               (Firefox)
   ```
   
   查看：
   - ICE Connection State 应该是 "connected" 或 "completed"
   - 应该有视频流数据接收

---

## 常见错误信息

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `ICE Gathering completed` 后无响应 | 信令模式问题或 WebSocket 断开 | 重新编译，检查 WebSocket |
| `ICE connection state: failed` | 网络不通或候选交换失败 | 检查防火墙，添加 STUN |
| `signaling state: have-local-offer` 卡住 | 设备未返回 answer | 检查设备日志 |
| `WebSocket connection failed` | WebSocket 服务未启动 | 重启设备服务 |

---

## 高级调试

### 使用 Chrome WebRTC 内部工具

1. 打开 `chrome://webrtc-internals`
2. 建立连接
3. 查看以下内容：
   - **Peer Connections** - 连接状态
   - **ICE Candidate Pairs** - 候选对状态
   - **Stats** - 统计数据

### 抓包分析

```bash
# 在设备上抓包
ssh root@<设备IP>
tcpdump -i any -w /tmp/webrtc.pcap portrange 10000-65535

# 下载并分析
scp root@<设备IP>:/tmp/webrtc.pcap .
wireshark webrtc.pcap
```

### 测试 ICE 连通性

```bash
# 使用 coturn 测试 STUN/TURN
turnutils_uclient -v stun.l.google.com
```

---

## 联系支持

如果以上方法都无法解决问题，请提供以下信息：

1. **浏览器控制台完整日志**
2. **设备端日志**（`/userdata/jetkvm/last.log`）
3. **WebRTC internals 导出**（从 `chrome://webrtc-internals` 下载）
4. **编译版本信息**：
   ```bash
   ssh root@<设备IP>
   /userdata/jetkvm/bin/jetkvm_app --version
   ```

---

## 预防措施

1. **始终使用匹配的编译版本**
   - 前端和后端必须同时编译和部署
   - 使用 `make build_dev` 而不是分别编译

2. **保持代码同步**
   ```bash
   git pull origin dev
   ```

3. **清理缓存**
   - 定期清理 `node_modules` 和 `static` 目录
   - 使用 `npm ci` 而不是 `npm install`

4. **测试网络环境**
   - 确保开发环境和设备在同一网络
   - 避免复杂的 NAT 环境
