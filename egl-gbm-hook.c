#define _GNU_SOURCE
#include <dlfcn.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

typedef void *EGLDisplay;
typedef void *EGLNativeDisplayType;
typedef int EGLint;
typedef unsigned int EGLenum;
#define EGL_NO_DISPLAY ((EGLDisplay)0)
#define EGL_PLATFORM_GBM_KHR 0x31D7

struct gbm_device;

static void hooklog(const char *msg) {
    FILE *f = fopen("/tmp/egl-hook.log", "a");
    if (!f)
        return;
    fprintf(f, "%s\n", msg);
    fclose(f);
}

static void *real_from(const char *lib, const char *sym) {
    void *h = dlopen(lib, RTLD_NOLOAD | RTLD_NOW);
    if (!h)
        h = dlopen(lib, RTLD_NOW);
    return h ? dlsym(h, sym) : NULL;
}

static EGLDisplay gbm_display(void) {
    static EGLDisplay dpy = EGL_NO_DISPLAY;
    static int inited;
    struct gbm_device *(*gbm_create_device)(int);
    EGLDisplay (*get_plat)(EGLenum, void *, const EGLint *);
    struct gbm_device *gbm;
    int fd;
    char buf[192];

    if (inited)
        return dpy;
    inited = 1;

    hooklog("gbm_display()");
    fd = open("/dev/dri/renderD128", O_RDWR);
    if (fd < 0)
        fd = open("/dev/dri/card0", O_RDWR);

    gbm_create_device = real_from("libgbm.so.1", "gbm_create_device");
    get_plat = real_from("libEGL.so.1", "eglGetPlatformDisplayEXT");
    if (!get_plat)
        get_plat = real_from("libEGL.so.1", "eglGetPlatformDisplay");

    if (!gbm_create_device || !get_plat || fd < 0) {
        snprintf(buf, sizeof(buf), "missing gbm/egl/fd fd=%d gbm=%p get=%p",
                 fd, (void *)gbm_create_device, (void *)get_plat);
        hooklog(buf);
        return EGL_NO_DISPLAY;
    }

    gbm = gbm_create_device(fd);
    dpy = get_plat(EGL_PLATFORM_GBM_KHR, gbm, NULL);
    snprintf(buf, sizeof(buf), "using GBM fd=%d gbm=%p dpy=%p", fd, (void *)gbm, (void *)dpy);
    hooklog(buf);
    fprintf(stderr, "egl-gbm-hook: %s\n", buf);
    return dpy;
}

EGLDisplay eglGetDisplay(EGLNativeDisplayType native) {
    (void)native;
    hooklog("eglGetDisplay");
    return gbm_display();
}

void *eglGetProcAddress(const char *name) {
    void *(*real)(const char *);

    if (name && strcmp(name, "eglGetDisplay") == 0)
        return (void *)eglGetDisplay;

    real = real_from("libEGL.so.1", "eglGetProcAddress");
    return real ? real(name) : NULL;
}

__attribute__((constructor)) static void init_hook(void) {
    hooklog("hook loaded");
}
