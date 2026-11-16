# CatOS Apps

[简体中文](README.zh-CN.md)

CatOS Apps is an OpenWrt package feed for modular network services and their LuCI interfaces. Packages are maintained independently and can be installed individually on compatible OpenWrt-based systems.

## Packages

| Core package | LuCI package | Purpose |
| --- | --- | --- |
| `catos-notify` | `luci-app-catos-notify` | System-event notifications and notification-provider integration |
| `catos-ddns` | `luci-app-catos-ddns` | Dynamic DNS management for routers and local-network hosts |
| `catos-acme` | `luci-app-catos-acme` | ACME certificate lifecycle and deployment management |

Each LuCI package depends on its corresponding core package. The core packages do not require LuCI.

> [!IMPORTANT]
> **Development status:** CatOS Notify has an initial functional implementation, including notification providers, system-event monitoring, templates, LuCI configuration and an opt-in HTTP receiver. It is awaiting SDK and real-device validation. CatOS DDNS and CatOS ACME remain early package skeletons. These packages are not yet production-ready.

CatOS Notify: [user guide](docs/notify.md) · [requirements (简体中文)](docs/notify-requirements.zh-CN.md).

## Add the source feed

Add the following line to `feeds.conf` in an OpenWrt buildroot or SDK:

```text
src-git catos https://github.com/AldenClark/CatOS-apps.git
```

Update the feed and install its package definitions:

```sh
./scripts/feeds update catos
./scripts/feeds install -a -p catos
```

Select the desired packages with `make menuconfig`, or build an individual package after configuring the target:

```sh
make package/feeds/catos/catos-notify/compile V=s
```

Use an SDK matching the target OpenWrt release and architecture. OpenWrt 24.10 produces `.ipk` packages, while OpenWrt 25.12 and later use `.apk` packages.

## Signed APK binary feed

The repository publishes two independently built, signed APK feeds for **OpenWrt 25.12** and **SNAPSHOT**. On a supported OpenWrt device, connect over SSH as root and run:

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

To enable the Simplified Chinese LuCI translation, also install `luci-i18n-catos-notify-zh-cn`. The interface follows the LuCI language setting and defaults to English when no translation is selected.

The script checks for APK v3, identifies the underlying OpenWrt branch from the device's **existing `distfeeds.list`**, installs the [repository public key](https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem), selects the corresponding [25.12](https://aldenclark.github.io/CatOS-apps/feeds/openwrt-25.12/all/packages.adb) or [SNAPSHOT](https://aldenclark.github.io/CatOS-apps/feeds/SNAPSHOT/all/packages.adb) signed index, and runs `apk update`. It **does not install any application packages**. You can also install `catos-notify`, `catos-ddns`, or `catos-acme` without LuCI.

All seven current APKs contain scripts and resources only (`PKGARCH=all`), so each OpenWrt branch needs one architecture-independent feed rather than per-CPU rebuilds. The branches still use **separate SDK builds** because architecture independence does not guarantee cross-release dependency compatibility. Custom-branded Snapshot firmware is supported when its existing OpenWrt base feeds can satisfy the dependencies. The binary feed does not support `opkg`.

See the [binary feed installation and publishing guide](docs/binary-feed.md). The setup script is published together with each successful **Publish signed APK feed** workflow deployment.

## Repository layout

```text
net/                 Core OpenWrt package definitions
luci/                LuCI application packages
scripts/             Repository validation tools
site/                Static binary feed landing page
.github/workflows/   Validation, SDK builds, and signed APK publication
```

The three services have separate packages and configuration namespaces. CatOS Notify exposes a JSON CLI and a local ubus interface for calls from other packages.

## Development

See [CONTRIBUTING.md](CONTRIBUTING.md) for package conventions and validation instructions. SDK package builds can also be started from the **Build packages** GitHub Actions workflow.

## License

Distributed under the [MIT License](LICENSE).
