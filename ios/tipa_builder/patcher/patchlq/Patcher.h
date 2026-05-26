#import <Foundation/Foundation.h>

@interface Patcher : NSObject

/// Patch a game region with the dylib
+ (BOOL)patchGame:(NSString *)region error:(NSError **)error;

/// Remove the dylib injection
+ (BOOL)unpatchGame:(NSError **)error;

@end
