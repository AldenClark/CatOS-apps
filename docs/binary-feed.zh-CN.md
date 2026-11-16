# APK 签名二进制软件源

[English](binary-feed.md)

CatOS Apps 提供适用于 OpenWrt 的 APK 签名软件源，包含核心应用软件包与 LuCI 管理界面。软件包依赖的 OpenWrt 系统组件由官方软件源提供。

## 兼容范围

当前分别使用两个 OpenWrt SDK 分支**独立构建和签名**：

| 系统基础软件包分支 | 已签名 APK 软件源 | 构建依据 |
| --- | --- | --- |
| OpenWrt 25.12 系列 | [`feeds/openwrt-25.12/all/packages.adb`](https://aldenclark.github.io/CatOS-apps/feeds/openwrt-25.12/all/packages.adb) | 25.12 SDK |
| OpenWrt SNAPSHOT | [`feeds/SNAPSHOT/all/packages.adb`](https://aldenclark.github.io/CatOS-apps/feeds/SNAPSHOT/all/packages.adb) | Snapshot SDK |

当前六个软件包均为脚本和资源文件，声明 `PKGARCH=all`，因此**同一 OpenWrt 分支内部**不需要为每种 CPU 架构重复编译。但架构无关不代表 25.12 与 Snapshot 的库 ABI 和运行依赖通用，因此两个签名软件源不混合发布。

安装脚本以 `/etc/apk/repositories.d/distfeeds.list` 中的基础软件源为判断依据，不以固件自定义的 `DISTRIB_RELEASE`、`DISTRIB_ARCH`、`apk --print-arch` 或内核版本推测兼容性。例如定制固件报告 `0.8.5-beta`，但实际使用 `/snapshots/packages/aarch64_cortex-a53/base/packages.adb`，就会选择 SNAPSHOT 软件源。依赖仍必须能够从设备现有的兼容软件源解析。

二进制软件源要求使用 APK v3。采用 `opkg` 的 OpenWrt 可通过[源码 Feed](../README.zh-CN.md#添加源码-feed) 自行编译。

**开发状态：** CatOS Notify 已有初步功能实现，尚待 SDK 构建与实际设备验证。CatOS DDNS 和 CatOS ACME 仍为软件包骨架。当前软件包暂不适用于生产环境。

下载地址通过 **Publish signed APK feed** 工作流部署。

## 在 OpenWrt 上安装软件源

SSH 登录支持的 OpenWrt 设备，以 root 身份执行：

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

该脚本会安装签名公钥、配置对应分支的软件源，并执行 `apk update`；可重复运行，**不会自动安装软件包**。运行前可以检查脚本源码：[feed.sh](../feed.sh)。脚本要求 APK v3，拒绝意外更换的签名公钥，并在新增配置后 `apk update` 失败时回滚本次改动。

如果固件没有可识别的基础软件源路径，可在**自行确认用户态 ABI 兼容**后明确指定分支：

```sh
ash /tmp/catos-feed.sh --channel SNAPSHOT
# 或：ash /tmp/catos-feed.sh --channel openwrt-25.12
```

若已有可识别的基础软件源，则不允许指定与之冲突的分支。

### 手动配置

也可以不使用脚本，手动配置：

1. 确认包管理器版本及现有基础软件源：

   ```sh
   apk --version
   cat /etc/apk/repositories.d/distfeeds.list
   ```

2. 下载用于校验软件源索引的公钥：

   ```sh
   mkdir -p /etc/apk/keys /etc/apk/repositories.d
   wget -O /etc/apk/keys/catos-apk.pem \
     https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem
   ```

3. 将与用户态分支匹配的 `packages.adb` 地址添加到 APK 配置（以下以 SNAPSHOT 为例）：

   ```sh
   repo="https://aldenclark.github.io/CatOS-apps/feeds/SNAPSHOT/all/packages.adb"
   grep -qxF "$repo" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
     printf '%s\n' "$repo" >> /etc/apk/repositories.d/customfeeds.list
   apk update
   ```

   OpenWrt 25.12 请改用 `https://aldenclark.github.io/CatOS-apps/feeds/openwrt-25.12/all/packages.adb`。

4. 按需安装软件包，例如：

   ```sh
   apk add luci-app-catos-notify luci-app-catos-ddns luci-app-catos-acme
   ```

三个核心软件包 `catos-notify`、`catos-ddns`、`catos-acme` 均可在不安装 LuCI 界面的情况下独立安装。

如果索引不可用，请检查 **25.12 和 SNAPSHOT 两个分支**是否均已部署到 GitHub Pages。`apk update` 应使用已安装的公钥验证签名，不要通过 `--allow-untrusted` 绕过签名或依赖错误。OpenWrt Snapshot 的用户态库 ABI 可能随更新发生变化，长期未更新的定制固件仍可能需要自行匹配 SDK。不要对 OpenWrt 进行全系统 `apk upgrade`。

## 维护者：签名密钥配置

APK 索引使用**长期保留的 P-256（prime256v1）EC 密钥**签名。请在受信任的工作站上生成一次，并将其保存于 Git 工作目录之外：

```sh
bash scripts/generate-apk-key.sh ../catos-apk-signing
```

妥善备份 `../catos-apk-signing/catos-apk-private.pem`。在 GitHub 仓库中创建名为 `CATOS_APK_PRIVATE_KEY` 的 Actions Secret，保存私钥 PEM 的完整内容。已登录 GitHub CLI 的维护者可使用：

```sh
gh secret set CATOS_APK_PRIVATE_KEY \
  --repo AldenClark/CatOS-apps \
  < ../catos-apk-signing/catos-apk-private.pem
```

私钥不得提交至仓库、上传为构建产物或公开分发。发布工作流会自动从私钥导出 `keys/catos-apk.pem` 公钥并与软件包索引一同发布。日常更新不得重新生成签名密钥。

## 维护者：发布流程

1. 进入仓库 **Settings → Pages**，将发布来源设为 **GitHub Actions**。
2. 确认已配置 `CATOS_APK_PRIVATE_KEY` Secret。
3. 进入 **Actions → Publish signed APK feed → Run workflow**，从 `main` 分支手动运行。工作流会**同时构建 25.12 与 SNAPSHOT**，不支持只发布其中一个分支。
4. 检查两套 SDK 构建与 GitHub Pages 部署是否成功。工作流要求每个分支恰好包含六个 CatOS APK，阻止混入其他包，并检查当前软件包仍为架构无关类型。
5. 访问[公开软件源页面](https://aldenclark.github.io/CatOS-apps/)，验证两个签名索引及支持设备上的 `apk update`，尤其要检查设备现有基础仓库能够满足生成的依赖。

发布采用手动触发。每次成功部署均包含**两个分支的完整产物**，更新 SNAPSHOT 不得意外删除 25.12。如果未来新增原生二进制，再按 CPU 架构增加 SDK 构建和软件源目录。源码 Feed 与 APK 二进制软件源独立维护。
