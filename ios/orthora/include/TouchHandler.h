#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

// Bridges Unity iOS touch events to our renderer/menu
@interface TouchHandler : NSObject

@property (nonatomic, class, readonly) TouchHandler *sharedInstance;
@property (nonatomic, readonly) CGPoint lastTouchPoint;
@property (nonatomic, readonly) BOOL isTouching;

@end

NS_ASSUME_NONNULL_END
