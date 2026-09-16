<div align="center">
    <img alt="NoxKVM logo" src="https://jetkvm.com/logo-blue.png" height="28">

### NoxKVM

[Discord](https://jetkvm.com/discord) | [Website](https://jetkvm.com) | [Issues](https://github.com/likeaturtle/NoxKVM/issues) | [文档](https://jetkvm.com/docs)

</div>

NoxKVM 是一个高性能、开源的 KVM over IP（键盘、视频、鼠标）解决方案，专为远程管理电脑、服务器和工作站而设计。无论是处理启动故障、安装操作系统、调整 BIOS 设置，还是远程操控设备，NoxKVM 都能胜任。

## 功能特性

- **超低延迟** - 1080p@60FPS 视频，H.264 编码，30-60ms 延迟，鼠标键盘交互流畅
- **免费远程访问** - 通过 JetKVM Cloud 使用 WebRTC 进行远程管理
- **可选 Tailscale 组网** - 内置 Tailscale 状态管理，支持自定义 [Headscale](https://headscale.net/) 端点
- **开源软件** - 基于 Go + TypeScript 开发，可通过 SSH 访问设备进行自定义

## 与上游的关系

本项目 fork 自 [jetkvm/kvm](https://github.com/jetkvm/kvm)，在此基础上做了以下改动：

### 构建与发布

- 自动化 GitHub Actions 发布流水线（`release.yml`）
- 腾讯云 COS 对象存储作为固件分发 CDN
- 通过 OTA 元数据自动触发 cos-index-repo 索引更新
- 新增本地交叉编译工具链脚本（`setup_toolchain.sh`）和编译指南

### 代码改动

- **OTA 更新源**：`config.go` 中 `DefaultAPIURL` 改为指向自建 COS 存储
- **GPG 签名密钥**：`internal/ota/gpg.go` 中 `rootKeyFingerprint` 替换为自签名密钥
- **镜像存储路径**：`usb_mass_storage.go` 中 `imagesFolder` 从 `/userdata/jetkvm/images` 改为 `/mnt/sdcard`，适配 SD 卡存储

### 文档

- 中文 README 和本地编译指南
- WebRTC ICE 连接卡住问题的解决方案

## 参与贡献

欢迎社区贡献！无论是改进固件、添加新功能还是完善文档，你的参与都很有价值。请阅读 [Code of Conduct](/CODE_OF_CONDUCT.md)。

## 获取帮助

- [文档](https://jetkvm.com/docs)
- [Discord 社区](https://jetkvm.com/discord)
- [提交 Issue](https://github.com/likeaturtle/NoxKVM/issues)

## 开发

项目使用 Go、TypeScript 和少量 C 编写。建议具备中等水平的 Go 和 TypeScript 知识。

项目包含两部分：运行在 KVM 设备上的后端和设备提供的前端（云端也使用同一前端）。

详细的开发信息（环境搭建、测试、调试、贡献指南）请参阅 **[DEVELOPMENT.md](DEVELOPMENT.md)**。

快速部署到设备可使用 `./dev_deploy.sh`，运行 `./dev_deploy.sh --help` 查看更多选项。

### 后端

Go 语言编写，负责 KVM 设备管理、云 API 和 Web 服务。

### 前端

React + TypeScript 编写，有三个构建目标：`device`（设备端）、`development`（本地开发）、`production`（云端部署）。

### 本地编译

详细的编译指南请参阅 **[本地编译指南](本地编译指南.md)**。

### 发布流程

通过 GitHub Actions 自动化发布：

1. 手动触发 `release.yml`，输入版本号（如 `0.5.6`）
2. 自动完成：构建 → 签名 → 创建 GitHub Release → 上传腾讯云 COS → 部署 OTA 元数据 → 触发 cos-index-repo 更新

所需 GitHub Secrets：

| Secret | 用途 |
|---|---|
| `GPG_PRIVATE_KEY` | GPG 签名私钥 |
| `GPG_PASSPHRASE` | GPG 私钥密码 |
| `TENCENT_SECRET_ID` | 腾讯云 SecretId |
| `TENCENT_SECRET_KEY` | 腾讯云 SecretKey |
| `TENCENT_COS_BUCKET` | COS 存储桶名称 |
| `TENCENT_COS_REGION` | COS 区域 |
| `COS_INDEX_PAT` | 触发 cos-index-repo 的 Personal Access Token |
