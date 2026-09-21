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

Personal Unraid settings (port 5556, DNS, APK mounts, `ROOT_SETUP`) stay in your local compose, not in this image.
