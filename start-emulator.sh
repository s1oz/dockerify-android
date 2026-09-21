#!/bin/bash

# Kill any running emulator instances before starting a new one
pkill -f "/opt/android-sdk/emulator/emulator"

# Removes .lock files before emulator starts to prevent crashes
rm -rf /data/android.avd/*.lock

# Use custom ramdisk if present
if [ -f /data/android.avd/ramdisk.img ]; then
  RAMDISK="-ramdisk /data/android.avd/ramdisk.img"
fi

# Path to the AVD config
CONFIG_FILE="/data/android.avd/config.ini"

update_config() {
  local key="$1"
  local value="$2"
  if grep -qE "^${key}[[:space:]]*=" "$CONFIG_FILE"; then
    sed -i "s/^${key}[[:space:]]*=.*/${key}=${value}/" "$CONFIG_FILE"
  else
    echo "$key=$value" >> "$CONFIG_FILE"
  fi
}

# Configure optional screen resolution and density directly via config.ini
if [ -f "$CONFIG_FILE" ]; then
  if [ -n "$SCREEN_RESOLUTION" ]; then
    WIDTH=${SCREEN_RESOLUTION%x*}
    HEIGHT=${SCREEN_RESOLUTION#*x}
    update_config "hw.lcd.width" "$WIDTH"
    update_config "hw.lcd.height" "$HEIGHT"
  fi
  if [ -n "$SCREEN_DENSITY" ]; then
    update_config "hw.lcd.density" "$SCREEN_DENSITY"
  fi
fi

# Default stays software (historical -gpu swiftshader_indirect).
# Set GPU_MODE=host and pass /dev/dri to use the host GPU.
case "${GPU_MODE:-swiftshader_indirect}" in
  swiftshader|software) GPU_MODE=swiftshader_indirect ;;
  "") GPU_MODE=swiftshader_indirect ;;
esac

if [ "$GPU_MODE" = "host" ] && [ ! -e /dev/dri/renderD128 ] && [ ! -e /dev/dri/card0 ]; then
  echo "GPU_MODE=host requested but no /dev/dri render node; falling back to swiftshader_indirect"
  GPU_MODE=swiftshader_indirect
fi

CPU_CORES="${CPU_CORES:-4}"
RAM_SIZE="${RAM_SIZE:-4096}"
REFRESH_RATE="${REFRESH_RATE:-60}"
if [ -f "$CONFIG_FILE" ]; then
  update_config "hw.gpu.enabled" "yes"
  update_config "hw.gpu.mode" "$GPU_MODE"
  update_config "hw.cpu.ncore" "$CPU_CORES"
  update_config "hw.ramSize" "$RAM_SIZE"
  update_config "hw.lcd.vsync" "$REFRESH_RATE"
fi

if [ "$GPU_MODE" = "host" ]; then
  # Mesa DRI is a system library; the emulator's bundled libc++ will not load it.
  export ANDROID_EMULATOR_USE_SYSTEM_LIBS="${ANDROID_EMULATOR_USE_SYSTEM_LIBS:-1}"
  export QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}"
  export LIBGL_ALWAYS_SOFTWARE=0
  export EGL_PLATFORM="${EGL_PLATFORM:-gbm}"
  unset GALLIUM_DRIVER
  unset MESA_LOADER_DRIVER_OVERRIDE
  if [ -z "$VK_ICD_FILENAMES" ] && [ -f /usr/share/vulkan/icd.d/intel_icd.x86_64.json ]; then
    export VK_ICD_FILENAMES=/usr/share/vulkan/icd.d/intel_icd.x86_64.json
  fi
  # gfxstream still opens X11. Prefer modesetting Xorg on /dev/dri/card0 so
  # GLX is Mesa iris; Xvfb is llvmpipe-only fallback. Viewing stays on scrcpy.
  export DISPLAY="${DISPLAY:-:99}"
  disp_num="${DISPLAY#:}"
  display_live() {
    [ -S "/tmp/.X11-unix/X${disp_num}" ] || return 1
    xdpyinfo -display "$DISPLAY" >/dev/null 2>&1
  }
  if ! display_live; then
    pkill -9 Xorg >/dev/null 2>&1 || true
    rm -f "/tmp/.X11-unix/X${disp_num}" "/tmp/.X${disp_num}-lock"
    mkdir -p /tmp/.X11-unix /var/log
    xorg_conf="${XORG_HEADLESS_CONF:-/etc/X11/xorg-headless.conf}"
    if command -v Xorg >/dev/null 2>&1 && [ -e /dev/dri/card0 ] && [ -f "$xorg_conf" ]; then
      Xorg "$DISPLAY" -config "$xorg_conf" -ac -noreset -nolisten tcp -logfile /tmp/xorg.log >/tmp/xorg-stdout.log 2>&1 &
      echo "Starting headless Xorg $DISPLAY on /dev/dri/card0 (modesetting/glamor)"
    else
      Xvfb "$DISPLAY" -screen 0 "${XVFB_SCREEN:-1280x720x24}" +extension GLX +extension RANDR +extension RENDER -ac -nolisten tcp >/tmp/xvfb.log 2>&1 &
      echo "Starting Xvfb $DISPLAY (software GL fallback)"
    fi
    for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
      display_live && break
      sleep 0.25
    done
  fi
  if ! display_live; then
    echo "Display $DISPLAY did not come up; host GPU GLX will fail"
  fi
  HOOK="${EGL_GBM_HOOK:-/usr/local/lib/libegl-gbm-hook.so}"
  if [ -f "$HOOK" ]; then
    export LD_PRELOAD="${HOOK}${LD_PRELOAD:+:$LD_PRELOAD}"
    echo "Using EGL GBM hook on /dev/dri/renderD128"
  fi
  export vblank_mode="${vblank_mode:-0}"
  export mesa_glthread="${mesa_glthread:-true}"
fi

echo "Starting emulator GPU_MODE=${GPU_MODE} cores=${CPU_CORES} ram=${RAM_SIZE} vsync=${REFRESH_RATE} dri=$(ls /dev/dri 2>/dev/null | tr '\n' ' ')"

# Start the emulator with the appropriate ramdisk.img
/opt/android-sdk/emulator/emulator -avd android -nojni -netfast -writable-system -no-window -no-audio -no-boot-anim -skip-adb-auth -gpu "$GPU_MODE" -cores "$CPU_CORES" -no-snapshot -no-metrics $RAMDISK -qemu -m "$RAM_SIZE"
