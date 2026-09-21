# s1oz fork: GPU image

This **`gpu`** branch is fork-only. It is not part of PR #54.

- Upstream: [Shmayro/dockerify-android](https://github.com/Shmayro/dockerify-android)
- GPU patches: same as `feat/host-gpu` (PR #54)
- Image: `ghcr.io/s1oz/dockerify-android`

Until the upstream PR is merged, pulling `shmayro/dockerify-android` will **not** include host GPU. This image rebases onto upstream `main` and rebuilds so you get the author's other changes **and** `GPU_MODE=host`.

## Enable the pipeline

1. GitHub → this fork → **Actions** → enable workflows.
2. Push to `gpu` (already done) or **Actions → Sync upstream and publish GPU image → Run workflow**.
3. First build downloads the Android SDK; expect 20–40 minutes.
4. Packages → `dockerify-android` → if the image is private, set visibility to **Public**.

## Pull

```bash
docker pull ghcr.io/s1oz/dockerify-android:latest
```

Tags: `latest`, `gpu`, `sha-<7>`, `YYYYMMDD`.

## Run with host GPU

See `docker-compose.gpu.yml`. Default compose on this branch still matches upstream (SwiftShader unless you set `GPU_MODE=host` and pass `/dev/dri`).

## What happens when Shmayro updates

Daily at 03:17 UTC the workflow rebases `gpu` onto `Shmayro/main`:

| Situation | Result |
|---|---|
| Upstream changed, rebase clean | Push `gpu`, rebuild image, GPU kept |
| Upstream unchanged | No rebuild |
| Rebase conflict | Workflow **fails**; image stays at last good build. Fix `gpu` by hand. |
| PR #54 merged upstream | Rebase usually becomes a no-op for GPU files; image still builds |

Blindly `docker pull shmayro/dockerify-android` after an upstream release does **not** keep GPU until they merge and publish that code.

Personal Unraid settings (port, DNS, RAM, CPU pin, `ROOT_SETUP`) live in the Unraid template / environment variables, not in the image. Updating `latest` keeps GPU and picks up new env-driven defaults; your GUI values win.

## Unraid GUI（推荐，和 redroid 一样管）

模板：[`unraid/my-dockerify-android.xml`](unraid/my-dockerify-android.xml)

1. 复制到 `/boot/config/plugins/dockerMan/templates-user/my-dockerify-android.xml`
2. Docker → 添加容器 → 模板选 `dockerify-android`
3. 变量在 GUI 里改，不要再 bind-mount `start-emulator.sh` / `first-boot.sh`（否则镜像自动更新改不了脚本）
4. CA Auto Update 勾选该容器，跟 `ghcr.io/s1oz/dockerify-android:latest`

环境变量（模板里都有中文说明）：`GPU_MODE` `DNS` `RAM_SIZE` `CPU_CORES` `REFRESH_RATE` `SHOW_FPS` `STAY_AWAKE` `SCREEN_RESOLUTION` `SCREEN_DENSITY` `ROOT_SETUP` `GAPPS_SETUP` `ARM_TRANSLATION`
