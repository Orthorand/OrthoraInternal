#import "TouchHandler.h"
#import <objc/runtime.h>
#import <objc/message.h>

#define LOGI(fmt, ...) NSLog(@"[Orthora-Touch] " fmt, ##__VA_ARGS__)

static TouchHandler *g_touchHandler = nil;
static void (*orig_touchesBegan)(id, SEL, NSSet *, UIEvent *);
static void (*orig_touchesMoved)(id, SEL, NSSet *, UIEvent *);
static void (*orig_touchesEnded)(id, SEL, NSSet *, UIEvent *);
static void (*orig_touchesCancelled)(id, SEL, NSSet *, UIEvent *);

// Hook Unity's view controller touch handling
// We hook UIApplication's sendEvent to capture all touches

static void (*orig_sendEvent)(id, SEL, UIEvent *);
static void Hooked_sendEvent(id self, SEL _cmd, UIEvent *event) {
    orig_sendEvent(self, _cmd, event);

    if (event.type == UIEventTypeTouches) {
        NSSet *touches = [event allTouches];
        for (UITouch *touch in touches) {
            CGPoint pt = [touch locationInView:nil];
            TouchHandler *handler = [TouchHandler sharedInstance];
            handler->_lastTouchPoint = pt;

            switch (touch.phase) {
                case UITouchPhaseBegan:
                    handler->_isTouching = YES;
                    LOGI(@"Touch began: (%.1f, %.1f)", pt.x, pt.y);
                    break;
                case UITouchPhaseMoved:
                    break;
                case UITouchPhaseEnded:
                case UITouchPhaseCancelled:
                    handler->_isTouching = NO;
                    break;
                default:
                    break;
            }
        }
    }
}

@implementation TouchHandler

+ (instancetype)sharedInstance {
    if (!g_touchHandler) {
        g_touchHandler = [[TouchHandler alloc] init];
    }
    return g_touchHandler;
}

- (instancetype)init {
    if ((self = [super init])) {
        _isTouching = NO;
        _lastTouchPoint = CGPointZero;
        [self installHook];
    }
    return self;
}

- (void)installHook {
    LOGI(@"Installing touch hook...");

    // Hook UIApplication sendEvent to capture all touches
    Method m = class_getInstanceMethod(
        objc_getClass("UIApplication"),
        @selector(sendEvent:)
    );
    if (m) {
        orig_sendEvent = (void (*)(id, SEL, UIEvent *))method_getImplementation(m);
        method_setImplementation(m, (IMP)Hooked_sendEvent);
        LOGI(@"Touch hook installed via sendEvent");
    }
}

@end
