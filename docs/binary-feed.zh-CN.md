# APK 签名二进制软件源

[English](binary-feed.md)

CatOS Apps 提供适用于 OpenWrt 的 APK 签名软件源，包含核心应用软件包与 LuCI 管理界面。软件包依赖的 OpenWrt 系统组件由官方软件源提供。

## 支持范围

| OpenWrt 版本 | APK 软件包架构 |
| --- | --- |
| 25.12.6 | `x86_64`、`aarch64_generic`、`mips_24kc` |

二进制软件源要求使用 APK 包管理器。采用 `opkg` 的 OpenWrt 24.10 可通过[源码 Feed](../README.zh-CN.md#添加源码-feed) 自行编译。

**开发状态：** CatOS Notify 已有初步功能实现，尚待 SDK 构建与实际设备验证。CatOS DDNS 和 CatOS ACME 仍为软件包骨架。当前软件包暂不适用于生产环境。

下载地址通过 **Publish signed APK feed** 工作流部署。

## 在 OpenWrt 上安装软件源

SSH 登录支持的 OpenWrt 设备，以 root 身份执行：

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

该脚本会安装签名公钥、匹配的软件源索引，并执行 `apk update`；可重复运行，**不会自动安装软件包**。运行前可以先检查脚本源码：[feed.sh](../feed.sh)。脚本会拒绝不支持的系统版本、架构，以及意外更换的签名公钥。

### 手动配置

也可以不使用脚本，手动配置：

1. 确认设备的 OpenWrt 版本与架构：

   ```sh
   . /etc/openwrt_release
   echo "$DISTRIB_RELEASE"
   apk --print-arch
   ```

2. 下载用于校验软件源索引的公钥：

   ```sh
   mkdir -p /etc/apk/keys /etc/apk/repositories.d
   wget -O /etc/apk/keys/catos-apk.pem \
     https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem
   ```

3. 将与设备版本、架构一致的 `packages.adb` 地址添加到 APK 配置：

   ```sh
   . /etc/openwrt_release
   arch="$(apk --print-arch)"
   repo="https://aldenclark.github.io/CatOS-apps/releases/${DISTRIB_RELEASE}/${arch}/packages.adb"
   grep -qxF "$repo" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
     printf '%s\n' "$repo" >> /etc/apk/repositories.d/customfeeds.list
   apk update
   ```

4. 按需安装软件包，例如：

   ```sh
   apk add luci-app-catos-notify luci-app-catos-ddns luci-app-catos-acme
   ```

三个核心软件包 `catos-notify`、`catos-ddns`、`catos-acme` 均可在不安装 LuCI 界面的情况下独立安装。

若索引无法下载，请检查目标 OpenWrt 版本与架构是否已经发布。执行 `apk update` 时，APK 应使用已安装的公钥验证软件源签名。

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

私钥不得提交至仓库、上传为构建产物或公开分发。发布工作流会自动从私钥导出 `keys/catos-apk.pem` 公钥并与软件包索引一同发布。日常更新不得重新生成签名密钥；密钥轮换需要制定独立的用户迁移方案。

## 维护者：发布流程

1. 进入仓库 **Settings → Pages**，将发布来源设为 **GitHub Actions**。
2. 确认已配置 `CATOS_APK_PRIVATE_KEY` Secret。
3. 进入 **Actions → Publish signed APK feed → Run workflow**，从 `main` 分支手动运行，选择受支持的 OpenWrt 版本。
4. 检查所有架构的构建与 GitHub Pages 部署是否成功。工作流会检查六个 CatOS 软件包是否齐全，并阻止发布包含非 CatOS 软件包的目录。
5. 访问 [CatOS APK 软件源](https://aldenclark.github.io/CatOS-apps/)，并在受支持设备上验证 `apk update`。

发布采用手动触发。每次成功发布均替换当前支持版本及架构对应的软件源快照。如需支持更多 OpenWrt 版本系列，应同步扩展发布工作流及历史版本保留策略。源码 Feed 与 APK 二进制软件源独立维护。
