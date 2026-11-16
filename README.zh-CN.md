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

请使用与目标 OpenWrt 版本及架构匹配的 SDK。OpenWrt 24.10 生成 `.ipk` 软件包，OpenWrt 25.12 及更新版本使用 `.apk`。本仓库是**源码 Feed**，不是可直接添加到设备上的二进制软件源。

## 仓库结构

```text
net/                 核心 OpenWrt 软件包定义
luci/                LuCI 应用软件包
scripts/             仓库检查工具
.github/workflows/   静态检查与手动 SDK 构建
```

三个应用分别维护软件包和配置命名空间。跨应用调用接口将在功能实现过程中逐步提供。

## 参与开发

软件包规范和检查方法见 [CONTRIBUTING.md](CONTRIBUTING.md)。也可以在 GitHub Actions 中手动运行 **Build packages** 工作流进行 SDK 构建。

## 许可证

本项目采用 [MIT License](LICENSE)。
