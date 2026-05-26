#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "IL2CPPDump.h"
#import "ESPHook.h"
#import "TouchHandler.h"
#import "MetalRenderer.h"

#define ORTH_LOG(fmt, ...) NSLog(@"[Orthora] " fmt, ##__VA_ARGS__)

// Module flags
typedef NS_OPTIONS(NSUInteger, OrthModule) {
    OrthModuleDump   = 1 << 0,
    OrthModuleESP    = 1 << 1,
    OrthModuleTouch  = 1 << 2,
};

static OrthModule g_enabled = OrthModuleDump | OrthModuleESP | OrthModuleTouch;
static MetalRenderer *g_renderer = nil;
static ESPHook *g_esp = nil;

// ============================================================
// Hook Unity's application delegate to inject our renderer
// ============================================================
static void (*orig_UIApplication_run)(id, SEL);
static void hook_UIApplication_run(id self, SEL _cmd) {
    ORTH_LOG(@"UIApplication run hooked - initializing Orthora");

    if (g_enabled & OrthModuleDump) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            ORTH_LOG(@"Starting IL2CPP dump...");
            IL2CPPDumpStart();
        });
    }

    if (g_enabled & OrthModuleESP) {
        g_esp = [[ESPHook alloc] init];
        [g_esp start];
    }

    if (g_enabled & OrthModuleTouch) {
        [TouchHandler sharedInstance];
    }

    // Hook Unity's main display link for Metal rendering
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(3.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        g_renderer = [[MetalRenderer alloc] init];
        [g_renderer start];
    });

    orig_UIApplication_run(self, _cmd);
}

// ============================================================
// Constructor (entry point when injected)
// ============================================================
__attribute__((constructor)) static void OrthoraInit() {
    ORTH_LOG(@"Orthora iOS loaded - hooking application");

    // Hook UIApplication run to initialize at game start
    MSHookMessageEx(
        objc_getClass("UIApplication"),
        @selector(run),
        (IMP)hook_UIApplication_run,
        (IMP *)&orig_UIApplication_run
    );
}
