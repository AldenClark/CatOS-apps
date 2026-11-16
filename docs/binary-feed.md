# Signed APK binary repository

[简体中文](binary-feed.zh-CN.md)

CatOS Apps provides a signed APK package repository for compatible OpenWrt systems. The repository contains the application packages and their LuCI interfaces; dependencies supplied by OpenWrt are resolved from the official OpenWrt repositories.

## Compatibility

The packages are built **separately** against two OpenWrt userspace branches:

| OpenWrt userspace | Signed APK feed | SDK build |
| --- | --- | --- |
| 25.12 series | [`feeds/openwrt-25.12/all/packages.adb`](https://aldenclark.github.io/CatOS-apps/feeds/openwrt-25.12/all/packages.adb) | OpenWrt 25.12 SDK |
| SNAPSHOT | [`feeds/SNAPSHOT/all/packages.adb`](https://aldenclark.github.io/CatOS-apps/feeds/SNAPSHOT/all/packages.adb) | OpenWrt Snapshot SDK |

Currently, all six packages contain only scripts and resources and are declared `PKGARCH=all`, so **each branch supports multiple CPU architectures without duplicate builds**. Architecture independence does **not** imply ABI or runtime dependency compatibility between 25.12 and SNAPSHOT; therefore, the two signed feeds are never combined.

The installation script detects the branch from `/etc/apk/repositories.d/distfeeds.list`, not from the firmware's custom `DISTRIB_RELEASE`, `DISTRIB_ARCH`, `apk --print-arch`, or kernel version. For example, a custom firmware reporting `0.8.5-beta` but using `/snapshots/packages/aarch64_cortex-a53/base/packages.adb` selects the SNAPSHOT feed. Its dependencies still need to be resolvable from its existing base repositories.

The binary repository requires APK v3. OpenWrt devices using `opkg` should use the [source feed](../README.md#add-the-source-feed) to build packages instead.

**Development status:** CatOS Notify has an initial functional implementation awaiting SDK and real-device validation. CatOS DDNS and CatOS ACME remain early package skeletons. These packages are not yet production-ready.

The download URLs are deployed through the **Publish signed APK feed** workflow.

## Install the repository on OpenWrt

Connect to a supported OpenWrt device over SSH as root, then run:

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

The script configures the signing key, selects the appropriate branch-specific signed index, and runs `apk update`. It is safe to run repeatedly and **does not install packages**. Inspect the script before running it: [feed.sh](../feed.sh). It requires APK v3, refuses unexpected signing-key changes, and rolls back newly made configuration changes when `apk update` fails.

If the firmware has no recognizable base feed URL, you can explicitly select a branch **only after confirming its ABI compatibility**:

```sh
ash /tmp/catos-feed.sh --channel SNAPSHOT
# or: ash /tmp/catos-feed.sh --channel openwrt-25.12
```

An explicit channel cannot override a conflicting, recognized base feed.

### Manual setup

You can also configure the repository without the setup script:

1. Confirm the APK version and existing base repositories:

   ```sh
   apk --version
   cat /etc/apk/repositories.d/distfeeds.list
   ```

2. Download the public signing key:

   ```sh
   mkdir -p /etc/apk/keys /etc/apk/repositories.d
   wget -O /etc/apk/keys/catos-apk.pem \
     https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem
   ```

3. Add **one** signed index matching the userspace branch (SNAPSHOT shown):

   ```sh
   repo="https://aldenclark.github.io/CatOS-apps/feeds/SNAPSHOT/all/packages.adb"
   grep -qxF "$repo" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
     printf '%s\n' "$repo" >> /etc/apk/repositories.d/customfeeds.list
   apk update
   ```

   For OpenWrt 25.12, use `https://aldenclark.github.io/CatOS-apps/feeds/openwrt-25.12/all/packages.adb` instead.

4. Install packages as needed, for example:

   ```sh
   apk add luci-app-catos-notify luci-app-catos-ddns luci-app-catos-acme
   ```

The core packages (`catos-notify`, `catos-ddns`, `catos-acme`) can also be installed without their LuCI interfaces.

If the index is unavailable, check that **both channel builds** were deployed successfully to GitHub Pages. `apk update` must verify the signed index with the installed public key; never use `--allow-untrusted` to bypass signature or dependency errors. OpenWrt SNAPSHOT can change userspace library ABI over time, so an older custom firmware may require its own matching build. Do not run a blanket `apk upgrade` on OpenWrt.

## Maintainer: signing key setup

APK repository indexes are signed with a **persistent P-256 (prime256v1) EC key**. Generate the key once, on a trusted workstation, outside the Git checkout:

```sh
bash scripts/generate-apk-key.sh ../catos-apk-signing
```

Back up `../catos-apk-signing/catos-apk-private.pem` in a secured location. Configure the repository's GitHub Actions secret named `CATOS_APK_PRIVATE_KEY` with the **complete PEM contents** of this private key. With GitHub CLI, an authenticated repository maintainer can use:

```sh
gh secret set CATOS_APK_PRIVATE_KEY \
  --repo AldenClark/CatOS-apps \
  < ../catos-apk-signing/catos-apk-private.pem
```

Never commit, attach, print, or distribute the private key. The publishing workflow derives `keys/catos-apk.pem` from the secret and serves the public key with the signed package indexes. Do not regenerate the signing key during normal releases: installed devices trust the existing public key.

## Maintainer: release publication

1. In repository **Settings → Pages**, choose **GitHub Actions** as the publishing source.
2. Confirm that the `CATOS_APK_PRIVATE_KEY` Actions secret is configured.
3. In **Actions → Publish signed APK feed → Run workflow**, run the workflow from the `main` branch. It builds **both** the 25.12 and SNAPSHOT channels; there is no single-channel deployment.
4. Verify that both SDK builds and the GitHub Pages deployment succeeded. The workflow requires exactly six CatOS APKs per channel and rejects unrelated packages. It also requires all current packages to remain architecture-independent.
5. Verify the [public landing page](https://aldenclark.github.io/CatOS-apps/), both signed APK indexes, and `apk update` on a suitable device. In particular, validate that the device's current base repositories can satisfy the generated dependencies.

Publishing is manual. Every successful deployment contains **both** channel feeds; a SNAPSHOT refresh must not remove 25.12 packages. If native binaries are added later, introduce separate CPU architecture builds and indexes. The repository's Git source feed remains available independently.
