#import "MetalRenderer.h"
#import "ESPHook.h"
#import <QuartzCore/QuartzCore.h>
#import <simd/simd.h>

#define LOGI(fmt, ...) NSLog(@"[Orthora-Render] " fmt, ##__VA_ARGS__)

// Simple vertex structure for our overlay
typedef struct {
    simd_float2 position;
    simd_float4 color;
} Vertex2D;

// Shader source - minimal passthrough
static NSString *const vertexShaderSrc = @R"(
#include <metal_stdlib>
using namespace metal;

struct VertexOut {
    float4 position [[position]];
    float4 color;
};

vertex VertexOut vertex_main(constant Vertex2D *vertices [[buffer(0)]],
                              uint vid [[vertex_id]]) {
    VertexOut out;
    out.position = float4(vertices[vid].position, 0.0, 1.0);
    out.color = vertices[vid].color;
    return out;
}

fragment float4 fragment_main(VertexOut in [[stage_in]]) {
    return in.color;
}
)";

@interface MetalRenderer ()
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, strong) CADisplayLink *displayLink;
@property (nonatomic, strong) UIWindow *overlayWindow;
@end

@implementation MetalRenderer

- (instancetype)init {
    if ((self = [super init])) {
        _device = MTLCreateSystemDefaultDevice();
        if (!_device) {
            LOGI(@"Metal not available, fallback to nil");
            return nil;
        }
        _commandQueue = [_device newCommandQueue];
    }
    return self;
}

- (void)start {
    LOGI(@"Starting Metal renderer...");

    // Create overlay window on top of everything
    dispatch_async(dispatch_get_main_queue(), ^{
        UIWindow *keyWindow = nil;
        if (@available(iOS 13.0, *)) {
            NSSet *scenes = [UIApplication sharedApplication].connectedScenes;
            for (UIWindowScene *scene in scenes) {
                if (scene.activationState == UISceneActivationStateForegroundActive) {
                    keyWindow = scene.windows.firstObject;
                    break;
                }
            }
        }
        if (!keyWindow) {
            keyWindow = [UIApplication sharedApplication].keyWindow;
        }

        if (!keyWindow) return;

        self.overlayWindow = [[UIWindow alloc] initWithFrame:keyWindow.bounds];
        self.overlayWindow.windowLevel = UIWindowLevelStatusBar + 100;
        self.overlayWindow.userInteractionEnabled = NO;
        self.overlayWindow.hidden = NO;
        self.overlayWindow.backgroundColor = [UIColor clearColor];

        UIViewController *vc = [[UIViewController alloc] init];
        vc.view.backgroundColor = [UIColor clearColor];
        vc.view.userInteractionEnabled = NO;

        // Create Metal layer
        self.metalLayer = [CAMetalLayer layer];
        self.metalLayer.device = self.device;
        self.metalLayer.pixelFormat = MTLPixelFormatBGRA8Unorm;
        self.metalLayer.framebufferOnly = YES;
        self.metalLayer.frame = vc.view.bounds;
        self.metalLayer.opaque = NO;
        [vc.view.layer addSublayer:self.metalLayer];

        self.overlayWindow.rootViewController = vc;
        [self.overlayWindow makeKeyAndVisible];

        // Compile shaders
        [self compileShaders];

        // Start display link
        self.displayLink = [CADisplayLink displayLinkWithTarget:self
                                                       selector:@selector(render)];
        [self.displayLink addToRunLoop:[NSRunLoop mainRunLoop]
                              forMode:NSRunLoopCommonModes];

        LOGI(@"Metal overlay ready");
    });
}

- (void)compileShaders {
    NSError *error = nil;
    id<MTLLibrary> library = [self.device newLibraryWithSource:vertexShaderSrc
                                                       options:nil
                                                         error:&error];
    if (error || !library) {
        LOGI(@"Shader compile error: %@", error);
        return;
    }

    id<MTLFunction> vertexFunc = [library newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunc = [library newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = vertexFunc;
    desc.fragmentFunction = fragmentFunc;
    desc.colorAttachments[0].pixelFormat = self.metalLayer.pixelFormat;

    // Enable blending for transparency
    desc.colorAttachments[0].blendingEnabled = YES;
    desc.colorAttachments[0].destinationRGBBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].sourceRGBBlendFactor = MTLBlendFactorSourceAlpha;
    desc.colorAttachments[0].destinationAlphaBlendFactor = MTLBlendFactorOneMinusSourceAlpha;
    desc.colorAttachments[0].sourceAlphaBlendFactor = MTLBlendFactorSourceAlpha;

    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:desc
                                                                     error:&error];
    if (error) LOGI(@"Pipeline error: %@", error);
}

- (void)render {
    @autoreleasepool {
        if (!self.metalLayer || !self.pipelineState) return;

        id<CAMetalDrawable> drawable = [self.metalLayer nextDrawable];
        if (!drawable) return;

        MTLRenderPassDescriptor *passDesc = [MTLRenderPassDescriptor renderPassDescriptor];
        passDesc.colorAttachments[0].texture = drawable.texture;
        passDesc.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDesc.colorAttachments[0].storeAction = MTLStoreActionStore;
        passDesc.colorAttachments[0].clearColor = MTLClearColorMake(0, 0, 0, 0);

        id<MTLCommandBuffer> cmdBuf = [self.commandQueue commandBuffer];
        id<MTLRenderCommandEncoder> encoder =
            [cmdBuf renderCommandEncoderWithDescriptor:passDesc];

        [encoder setRenderPipelineState:self.pipelineState];

        // Get ESP data
        NSArray *players = [[ESPHook sharedInstance] playerData];
        CGFloat w = self.metalLayer.frame.size.width;
        CGFloat h = self.metalLayer.frame.size.height;

        // Convert to normalized device coordinates (-1 to 1)
        // Draw ESP visuals
        for (NSDictionary *p in players) {
            float hp = [p[@"hp"] floatValue];
            float maxHp = [p[@"maxHp"] floatValue];
            BOOL isEnemy = [p[@"isEnemy"] boolValue];

            // Simple box at fixed screen position for demo
            float boxX = 0.2f + ([p[@"configID"] intValue] % 10) * 0.06f;
            float boxY = 0.1f;
            float boxW = 0.04f;
            float boxH = 0.15f;

            // Convert to NDC
            float ndcL = (boxX / w * 2.0f) - 1.0f;
            float ndcR = ((boxX + boxW) / w * 2.0f) - 1.0f;
            float ndcT = 1.0f - (boxY / h * 2.0f);
            float ndcB = 1.0f - ((boxY + boxH) / h * 2.0f);

            simd_float4 color = isEnemy ?
                (simd_float4){1, 0, 0, 0.8f} : (simd_float4){0, 1, 0, 0.8f};

            // Box corners (line strip)
            Vertex2D verts[] = {
                { { ndcL, ndcT }, color },
                { { ndcR, ndcT }, color },
                { { ndcR, ndcB }, color },
                { { ndcL, ndcB }, color },
                { { ndcL, ndcT }, color },
            };

            [encoder setVertexBytes:verts
                            length:sizeof(verts)
                           atIndex:0];
            [encoder drawPrimitives:MTLPrimitiveTypeLineStrip
                        vertexStart:0
                        vertexCount:5];
        }

        [encoder endEncoding];
        [cmdBuf presentDrawable:drawable];
        [cmdBuf commit];
    }
}

@end
