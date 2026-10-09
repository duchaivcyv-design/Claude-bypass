# ClaudeGuard

Tweak iOS giả iOS 18 + chặn mọi đường check update cho app Claude.

## Cài

### Cách 1 — Repo Sileo/Zebra
Thêm repo: `https://<user>.github.io/<repo>/`
Cài `Claude iOS Guard`.

### Cách 2 — Deb thủ công
Tải từ [Releases](../../releases):
- `ClaudeGuard-rootful.deb` → unc0ver, Taurine, checkra1n
- `ClaudeGuard-rootless.deb` → Dopamine 1.x, Palera1n, XinaA15
- `ClaudeGuard-roothide.deb` → Dopamine 2.x, Bootstrap

Mở Filza → cài → respring.

## Build local

```bash
export THEOS=$HOME/theos
./scripts/build-deb.sh
