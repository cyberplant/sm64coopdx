# Docker (headless dedicated server)

Build a dedicated server image **without** embedding a Super Mario 64 ROM.
Place a legally obtained vanilla **US** ROM at runtime as `baserom.us.z64`.

## Build

```bash
docker build -t sm64coopdx:headless .
```

Multi-arch (amd64 + arm64):

```bash
docker buildx build --platform linux/amd64,linux/arm64 -t sm64coopdx:headless --load .
```

CI on this fork pushes to `ghcr.io/cyberplant/sm64coopdx:headless`.

## Run

```bash
mkdir -p ./data
cp /path/to/baserom.us.z64 ./data/baserom.us.z64

docker run --rm -p 7777:7777/udp \
  -v "$(pwd)/data:/data" \
  sm64coopdx:headless
```

Default args: `--headless --server 7777 --savepath /data --hide-loading-screen --skip-update-check --no-discord`.

Headless skips the software renderer (`gfx_run_dl`) and paces the game/network loop at 30 Hz, so a dedicated server should use a fraction of a core instead of pegging one.

Use `--enable-all-mods` to turn on every mod under the savepath `mods/` directory (recommended for dedicated servers). Names starting with `.` (e.g. `mods/.disabled/…`) are ignored by the loader — park unused packs there. Per-mod `--enable-mod NAME` still works when you want an explicit list.

The image ships the stripped binary plus `dynos` / `lang` / `palettes` only (no bundled mods, no Mesa DRI/LLVM). Put optional mods next to the ROM under the `/data` mount.

Override at the end of `docker run`, for example:

```bash
docker run --rm -p 7777:7777/udp -v "$(pwd)/data:/data" sm64coopdx:headless \
  --headless --server 7777 --savepath /data --hide-loading-screen \
  --playername "Roji" --playercount 8
```

Clients join via **Direct Connection** to `host:7777` (UDP).

## Toolchain-only image

```bash
docker build --target build -t sm64coopdx:build .
docker run --rm -v "$(pwd)":/src -w /src sm64coopdx:build make -j"$(nproc)"
```
