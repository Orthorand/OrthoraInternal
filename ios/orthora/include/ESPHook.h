#pragma once

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <simd/simd.h>

NS_ASSUME_NONNULL_BEGIN

@interface ESPHook : NSObject

@property (nonatomic, class, readonly) ESPHook *sharedInstance;

- (void)start;
- (void)updatePlayers;
- (NSArray<NSDictionary *> *)playerData;

@end

// Player data structure for rendering
typedef struct {
    simd_float3 worldPos;
    simd_float2 screenPos;
    float distance;
    int hp;
    int maxHp;
    int configID;
    BOOL isEnemy;
    BOOL visible;
    int skillCDs[5];
} ESPPlayerData;

NS_ASSUME_NONNULL_END
