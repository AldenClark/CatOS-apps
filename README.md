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

The repository includes an independently signed binary feed publishing workflow for OpenWrt 25.12.6. Once its first release has been published, users can install the [repository public key](https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem) and add the matching `packages.adb` URL to their OpenWrt APK repositories.

Supported publishing targets are `x86_64`, `aarch64_generic`, and `mips_24kc`. The binary feed is not compatible with OpenWrt 24.10's `opkg` package manager.

See the [binary feed installation and publishing guide](docs/binary-feed.md). Repository URLs become available after the first successful **Publish signed APK feed** workflow deployment.

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
