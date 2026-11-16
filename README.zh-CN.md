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
> **开发状态：** 当前仓库提供可构建的软件包定义、初始 UCI 配置文件以及 LuCI 页面骨架。通知投递、动态 DNS 更新和证书签发功能尚未实现，暂不适用于生产环境。

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

本仓库包含面向 OpenWrt 25.12.6 的 APK 软件源构建、签名及发布工作流。首次成功发布后，用户可下载[软件源公钥](https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem)，并在 OpenWrt 的 APK 配置中添加与系统版本及架构对应的 `packages.adb` 地址。

目前发布配置包含 `x86_64`、`aarch64_generic` 和 `mips_24kc` 三种架构。二进制软件源不适用于使用 `opkg` 的 OpenWrt 24.10。

参见[APK 软件源安装与发布说明](docs/binary-feed.zh-CN.md)。公开下载地址将在 **Publish signed APK feed** 工作流首次成功部署后生效。

## 仓库结构

```text
net/                 核心 OpenWrt 软件包定义
luci/                LuCI 应用软件包
scripts/             仓库检查工具
site/                二进制软件源静态页面
.github/workflows/   静态检查、SDK 构建与已签名 APK 发布
```

三个应用分别维护软件包和配置命名空间。跨应用调用接口将在功能实现过程中逐步提供。

## 参与开发

软件包规范和检查方法见 [CONTRIBUTING.md](CONTRIBUTING.md)。也可以在 GitHub Actions 中手动运行 **Build packages** 工作流进行 SDK 构建。

## 许可证

本项目采用 [MIT License](LICENSE)。
