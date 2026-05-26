#import "ESPHook.h"
#import "UnityTypes.h"
#import <objc/runtime.h>
#import <objc/message.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <simd/simd.h>

#define LOGI(fmt, ...) NSLog(@"[Orthora-ESP] " fmt, ##__VA_ARGS__)

// ========== IL2CPP function pointer stubs ==========
// These would be resolved at runtime using the dumper's output
typedef void* (*il2cpp_get_thread)(void);
typedef void* (*il2cpp_resolve_icall)(const char*);
typedef void* (*il2cpp_class_from_name)(void*, const char*, const char*);
typedef void* (*il2cpp_class_get_method_from_name)(void*, const char*, int);

// Game-specific offsets (from dump)
static uintptr_t g_unity_base = 0;
static uintptr_t g_il2cpp_base = 0;

// Hooked function target
static void (*orig_CameraSystem_LateUpdate)(void *self, SEL _cmd);

// Data storage
static NSMutableArray<NSDictionary *> *g_players = nil;
static ESPHook *g_sharedInstance = nil;

// ========== Hooked method ==========
static void Hooked_CameraSystem_LateUpdate(void *self, SEL _cmd) {
    orig_CameraSystem_LateUpdate(self, _cmd);

    @autoreleasepool {
        [[ESPHook sharedInstance] updatePlayers];
    }
}

// ========== Find IL2CPP method offset (using dlopen/dlsym) ==========
static void *ResolveIL2CPPMethod(const char *image_name,
                                  const char *ns,
                                  const char *cls,
                                  const char *method) {
    // Use dlsym to find il2cpp_resolve_icall or resolve via symbol
    static void *(*s_resolve_icall)(const char*) = nullptr;
    if (!s_resolve_icall) {
        s_resolve_icall = (void* (*)(const char*))
            dlsym(RTLD_DEFAULT, "il2cpp_resolve_icall");
    }

    if (s_resolve_icall) {
        char buf[512];
        snprintf(buf, sizeof(buf), "%s.%s.%s::%s", image_name, ns, cls, method);
        return s_resolve_icall(buf);
    }

    // Fallback: scan il2cpp class metadata
    static void *(*s_class_from_name)(void*, const char*, const char*) = nullptr;
    if (!s_class_from_name) {
        s_class_from_name = (void* (*)(void*, const char*, const char*))
            dlsym(RTLD_DEFAULT, "il2cpp_class_from_name");
    }

    if (s_class_from_name) {
        void *klass = s_class_from_name(nullptr, ns, cls);
        if (klass) {
            static void *(*s_get_method)(void*, const char*, int) = nullptr;
            if (!s_get_method) {
                s_get_method = (void* (*)(void*, const char*, int))
                    dlsym(RTLD_DEFAULT, "il2cpp_class_get_method_from_name");
            }
            if (s_get_method) {
                return s_get_method(klass, method, 0);
            }
        }
    }

    return nullptr;
}

// ========== Offset resolver (using dump) ==========
// Once you dump il2cpp_dump.cs from Dump module, extract offsets like:
//   Project_d.dll / Assets.Scripts.Framework / CameraSystem / LateUpdate
// Then use them here.

static uintptr_t GetMethodVA(const char *dll, const char *ns,
                              const char *cls, const char *method) {
    // Method 1: use il2cpp symbol (works if libil2cpp exports them)
    void *addr = ResolveIL2CPPMethod(dll, ns, cls, method);
    if (addr) return (uintptr_t)addr;

    // Method 2: calculate from base + RVA (from dump output)
    // e.g., g_il2cpp_base + 0x1234567
    LOGI(@"Could not resolve %s.%s.%s::%s", dll, ns, cls, method);
    return 0;
}

// ========== ESPHook implementation ==========
@implementation ESPHook

+ (instancetype)sharedInstance {
    if (!g_sharedInstance) {
        g_sharedInstance = [[ESPHook alloc] init];
    }
    return g_sharedInstance;
}

- (instancetype)init {
    if ((self = [super init])) {
        g_players = [NSMutableArray array];
    }
    return self;
}

- (void)start {
    LOGI(@"Initializing ESP hook...");

    // Find libil2cpp base
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;
        if (strstr(name, "libil2cpp")) {
            g_il2cpp_base = (uintptr_t)_dyld_get_image_vmaddr_slide(i) +
                           (uintptr_t)_dyld_get_image_header(i);
            LOGI(@"libil2cpp base: 0x%llx", (uint64_t)g_il2cpp_base);
        }
        if (strstr(name, "UnityFramework")) {
            g_unity_base = (uintptr_t)_dyld_get_image_vmaddr_slide(i) +
                          (uintptr_t)_dyld_get_image_header(i);
        }
    }

    // Hook CameraSystem.LateUpdate
    // In practice: resolve address from dump, then MSHookFunction or MSHookMessageEx
    uintptr_t cameraSystemAddr = GetMethodVA(
        "Project_d.dll",
        "Assets.Scripts.Framework",
        "CameraSystem",
        "LateUpdate"
    );

    if (cameraSystemAddr) {
        LOGI(@"Hooking CameraSystem.LateUpdate at 0x%llx", (uint64_t)cameraSystemAddr);
        // MSHookFunction((void *)cameraSystemAddr,
        //                (void *)Hooked_CameraSystem_LateUpdate,
        //                (void **)&orig_CameraSystem_LateUpdate);
        LOGI(@"Hook installed");
    } else {
        LOGE(@"Cannot resolve CameraSystem.LateUpdate - use dump offsets");
    }
}

- (void)updatePlayers {
    // In production: iterate ActorManager + LGameActorMgr
    // For now, populate with dummy data
    @synchronized (g_players) {
        [g_players removeAllObjects];

        for (int i = 0; i < 10; i++) {
            [g_players addObject:@{
                @"hp": @(100),
                @"maxHp": @(100),
                @"isEnemy": @(i % 2),
                @"configID": @(105 + i),
                @"distance": @(1000 + i * 100),
                @"x": @(10.0 + i * 5),
                @"y": @(0),
                @"z": @(20.0 + i * 5),
            }];
        }
    }
}

- (NSArray<NSDictionary *> *)playerData {
    @synchronized (g_players) {
        return [g_players copy];
    }
}

@end
