# Frozen official release inputs

Checked 2026-10-04. Public upstream files only; no user profile or runtime data.

- `cli-package.json`: exact `package/package.json` from the [official CLI tarball](https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-0.2.0-rc.2.tgz), after checking npm SHA-512 integrity.
- `minimal.patch.yml`: exact [release-tagged Minimal declaration](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/packages/bundle/web-app/presets/minimal.patch.yml).
- `release.json`: dated registry channels, integrity, and SHA-256 hashes of both files.

The copied files are Copyright (c) 2026 DeepSeek, under the upstream [MIT license](https://github.com/deepseek-ai/deepseek-harness/blob/dsh-v0.2.0-rc.2/LICENSE). See this repository's [NOTICE](../../../NOTICE) and [LICENSE](../../../LICENSE).
