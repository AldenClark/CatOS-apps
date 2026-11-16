# Contributing to CatOS Apps

Contributions are welcome. Please use a focused pull request for each change and describe the affected packages and OpenWrt versions.

## Package conventions

- Keep each core service independent of the other application packages.
- Place core package definitions under `net/` and LuCI packages under `luci/`.
- Use the `catos-` prefix for core packages and `luci-app-catos-` for LuCI packages.
- Use a separate UCI configuration namespace for each core package.
- Use upstream OpenWrt package conventions and the current LuCI JavaScript framework.
- Do not include credentials, device-specific secrets, or generated build artifacts in commits.
- Document supported behavior accurately. A package definition or UI placeholder does not imply that its service is functional.

## Local validation

Run the repository checks before submitting a change:

```sh
bash scripts/check-feed.sh
```

For integration validation, add the repository as a source feed to a matching OpenWrt SDK and compile each affected package. The manually triggered **Build packages** workflow offers an additional SDK build path.

## Pull requests

Include a concise change summary, relevant testing results, and any changes to dependencies or user-visible configuration. Breaking changes to configuration or inter-package interfaces should be called out explicitly.
