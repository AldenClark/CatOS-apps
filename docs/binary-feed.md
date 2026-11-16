# Signed APK binary repository

[简体中文](binary-feed.zh-CN.md)

CatOS Apps provides a signed APK package repository for compatible OpenWrt systems. The repository contains the application packages and their LuCI interfaces; dependencies supplied by OpenWrt are resolved from the official OpenWrt repositories.

## Compatibility

The **universal feed** contains only packages declared with architecture `all` and targets compatible OpenWrt-based systems using APK v3. Branded firmware version numbers do not affect feed selection. Package dependencies must still be available from the device's own compatible repositories.

The following release-specific feed snapshots remain available:

| OpenWrt release | APK architectures |
| --- | --- |
| 25.12.6 | `x86_64`, `aarch64_generic`, `mips_24kc` |

The binary repository requires APK v3. OpenWrt devices using `opkg` should use the [source feed](../README.md#add-the-source-feed) to build packages instead.

**Development status:** CatOS Notify has an initial functional implementation awaiting SDK and real-device validation. CatOS DDNS and CatOS ACME remain early package skeletons. These packages are not yet production-ready.

The download URLs are deployed through the **Publish signed APK feed** workflow.

## Install the repository on OpenWrt

Connect to a supported OpenWrt device over SSH as root, then run:

```sh
wget -O /tmp/catos-feed.sh https://aldenclark.github.io/CatOS-apps/feed.sh && ash /tmp/catos-feed.sh
apk add luci-app-catos-notify
```

The script configures the signing key, selects the universal signed index, and runs `apk update`. It is safe to run again and **does not install packages**. Inspect the script before running it: [feed.sh](../feed.sh). It requires APK v3 and rejects unexpected signing-key changes.

### Manual setup

You can also configure the repository without the setup script:

1. Confirm the package manager and architecture:

   ```sh
   apk --version
   apk --print-arch
   ```

2. Download the public signing key:

   ```sh
   mkdir -p /etc/apk/keys /etc/apk/repositories.d
   wget -O /etc/apk/keys/catos-apk.pem \
     https://aldenclark.github.io/CatOS-apps/keys/catos-apk.pem
   ```

3. Add the universal signed index:

   ```sh
   repo="https://aldenclark.github.io/CatOS-apps/universal/packages.adb"
   grep -qxF "$repo" /etc/apk/repositories.d/customfeeds.list 2>/dev/null || \
     printf '%s\n' "$repo" >> /etc/apk/repositories.d/customfeeds.list
   apk update
   ```

4. Install packages as needed, for example:

   ```sh
   apk add luci-app-catos-notify luci-app-catos-ddns luci-app-catos-acme
   ```

The core packages (`catos-notify`, `catos-ddns`, `catos-acme`) can also be installed without their LuCI interfaces.

If the index is unavailable, confirm that the latest universal feed was published to GitHub Pages. A successful `apk update` must verify the repository signature against the installed public key. Universal package architecture does not waive runtime dependency compatibility.

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

Never commit, attach, print, or distribute the private key. The publishing workflow derives `keys/catos-apk.pem` from the secret and serves the public key with the signed package indexes. Do not regenerate the signing key during normal releases: installed devices trust the existing public key. Key rotation requires a separately planned user migration.

## Maintainer: release publication

1. In repository **Settings → Pages**, choose **GitHub Actions** as the publishing source.
2. Confirm that the `CATOS_APK_PRIVATE_KEY` Actions secret is configured.
3. In **Actions → Publish signed APK feed → Run workflow**, select the supported OpenWrt version and run the workflow from the `main` branch.
4. Verify that every architecture build and the GitHub Pages deployment succeeded. The workflow checks that all six CatOS packages were produced and rejects unexpected packages before uploading the feed.
5. Verify the public landing page at [CatOS APK repository](https://aldenclark.github.io/CatOS-apps/) and test `apk update` on a supported device.

Publishing is manual. Successful runs replace the published snapshot for the supported release and architecture set. Expand the workflow and its retention strategy before introducing additional OpenWrt release lines. The GitHub Pages content is a binary package repository; the repository's Git source feed remains available independently.
