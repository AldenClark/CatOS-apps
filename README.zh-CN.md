# CatOS Apps

[English](README.md)

CatOS Apps 是面向 OpenWrt 及兼容系统的模块化应用软件包源，包含独立的核心软件包及对应的 LuCI 管理界面。各应用可按需独立安装。

## 软件包

| 核心软件包 | LuCI 软件包 | 用途 |
| --- | --- | --- |
| `catos-notify` | `luci-app-catos-notify` | 系统事件通知与通知服务商集成 |
| `catos-ddns` | `luci-app-catos-ddns` | 路由器及局域网设备的动态 DNS 管理 |
| `catos-acme` | `luci-app-catos-acme` | ACME 证书签发、续期与部署管理 |

LuCI 软件包依赖对应的核心软件包；核心软件包无需依赖 LuCI。

> [!IMPORTANT]
> **开发状态：** CatOS Notify 已具备通知渠道、系统事件、模板、LuCI 配置和可选 HTTP 消息接收器的初步功能实现，尚待 SDK 构建及真实设备验证。CatOS DDNS 和 CatOS ACME 仍为软件包骨架。当前版本暂不建议用于生产环境。

通知服务文档：[使用及集成说明](docs/notify.md) · [详细需求规格](docs/notify-requirements.zh-CN.md)。

## 添加源码 Feed

在 OpenWrt 构建目录或 SDK 的 `feeds.conf` 中增加：

```text
src-git catos https://github.com/AldenClark/CatOS-apps.git
```

更新并注册软件包：

```sh
./scripts/feeds update catos
./scripts/feeds install -a -p catos
```

通过 `make menuconfig` 选择所需软件包。配置目标平台后，也可单独编译：

```sh
make package/feeds/catos/catos-notify/compile V=s
```

请使用与目标 OpenWrt 版本及架构匹配的 SDK。OpenWrt 24.10 生成 `.ipk` 软件包，OpenWrt 25.12 及更新版本使用 `.apk`。

## 已签名 APK 二进制软件源

本仓库包含面向 OpenWrt 25.12.6 的 APK 软件源构建、签名及发布工作流。在支持的 OpenWrt 设备上，以 root 身份通过 SSH 执行：

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

安装脚本会校验 OpenWrt 精确版本及 APK 架构，下载[软件源公钥](https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem)，写入匹配的 `packages.adb` 地址，并执行 `apk update`。脚本**不会自动安装任何应用软件包**。如不需要 LuCI，也可以单独安装 `catos-notify`、`catos-ddns` 或 `catos-acme`。

目前发布配置包含 `x86_64`、`aarch64_generic` 和 `mips_24kc` 三种架构。二进制软件源不适用于使用 `opkg` 的 OpenWrt 24.10。

参见[APK 软件源安装与发布说明](docs/binary-feed.zh-CN.md)。安装脚本会随每次成功运行的 **Publish signed APK feed** 工作流同步发布。

## 仓库结构

```text
net/                 核心 OpenWrt 软件包定义
luci/                LuCI 应用软件包
scripts/             仓库检查工具
site/                二进制软件源静态页面
.github/workflows/   静态检查、SDK 构建与已签名 APK 发布
```

三个应用分别维护软件包和配置命名空间。CatOS Notify 已为其他软件包提供 JSON 命令行和本机 ubus 接口。

## 参与开发

软件包规范和检查方法见 [CONTRIBUTING.md](CONTRIBUTING.md)。也可以在 GitHub Actions 中手动运行 **Build packages** 工作流进行 SDK 构建。

## 许可证

本项目采用 [MIT License](LICENSE)。
