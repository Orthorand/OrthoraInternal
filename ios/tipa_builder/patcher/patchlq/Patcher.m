#import "Patcher.h"
#import <spawn.h>
#import <sys/stat.h>
#import <dlfcn.h>

// The patcher works by:
// 1. Unzipping the dylib from bundled zip
// 2. Copying dylib to game's Frameworks/AWSS3.framework/
// 3. Using insert_dylib to add the dylib load command to game binary
// 4. Fixing permissions

@implementation Patcher

+ (NSString *)gameBundleIDForRegion:(NSString *)region {
    return [NSString stringWithFormat:@"com.garena.game.%@", region];
}

+ (NSString *)gamePathForRegion:(NSString *)region {
    NSString *bundleID = [self gameBundleIDForRegion:region];

    // Try standard app locations
    NSArray *paths = @[
        @"/var/containers/Bundle/Application",
        @"/private/var/containers/Bundle/Application",
    ];

    NSFileManager *fm = [NSFileManager defaultManager];
    for (NSString *basePath in paths) {
        NSArray *apps = [fm contentsOfDirectoryAtPath:basePath error:nil];
        for (NSString *appDir in apps) {
            NSString *appPath = [basePath stringByAppendingPathComponent:appDir];
            NSString *metaPath = [appPath stringByAppendingPathComponent:@"iTunesMetadata.plist"];
            NSDictionary *meta = [NSDictionary dictionaryWithContentsOfFile:metaPath];
            NSString *bid = meta[@"itemId"] ? bundleID : nil;

            // Alternative: search .app directories
            NSArray *contents = [fm contentsOfDirectoryAtPath:appPath error:nil];
            for (NSString *item in contents) {
                if ([item hasSuffix:@".app"]) {
                    NSString *plistPath = [appPath stringByAppendingPathComponent:
                        [item stringByAppendingPathComponent:@"Info.plist"]];
                    NSDictionary *info = [NSDictionary dictionaryWithContentsOfFile:plistPath];
                    if ([info[@"CFBundleIdentifier"] isEqualToString:bundleID]) {
                        return [appPath stringByAppendingPathComponent:item];
                    }
                }
            }
        }
    }

    // Fallback: use MobileContainerManager
    Class MCMClass = NSClassFromString(@"MCMAppContainer");
    if (MCMClass) {
        id container = [MCMClass performSelector:@selector(containerWithIdentifier:error:)
                                      withObject:bundleID withObject:nil];
        NSString *path = [container performSelector:@selector(containerPath)];
        if (path) {
            NSArray *contents = [fm contentsOfDirectoryAtPath:path error:nil];
            for (NSString *item in contents) {
                if ([item hasSuffix:@".app"]) {
                    return [path stringByAppendingPathComponent:item];
                }
            }
        }
    }

    // Last resort: search via lsregister
    NSString *output = [self runCommand:@"/usr/bin/xcrun" args:@[@"lsregister", @"-dump"]];
    NSArray *lines = [output componentsSeparatedByString:@"\n"];
    for (NSString *line in lines) {
        if ([line containsString:bundleID]) {
            for (NSString *nextLine in lines) {
                if ([nextLine containsString:@".app"]) {
                    // Extract path
                    NSRange r = [nextLine rangeOfString:@"/"];
                    if (r.location != NSNotFound) {
                        NSString *path = [nextLine substringFromIndex:r.location];
                        path = [path stringByTrimmingCharactersInSet:
                                [NSCharacterSet whitespaceCharacterSet]];
                        if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                            return path;
                        }
                    }
                    break;
                }
            }
        }
    }

    return nil;
}

+ (BOOL)patchGame:(NSString *)region error:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    // 1. Find game
    NSString *gamePath = [self gamePathForRegion:region];
    if (!gamePath) {
        if (error) *error = [NSError errorWithDomain:@"Orthora" code:1
            userInfo:@{NSLocalizedDescriptionKey: @"Game not found. Install it first."}];
        return NO;
    }

    NSString *gameExec = [gamePath stringByAppendingPathComponent:
                           [gamePath lastPathComponent].stringByDeletingPathExtension];
    if (![fm fileExistsAtPath:gameExec]) {
        gameExec = gamePath; // fallback
    }

    // 2. Get our dylib path
    NSString *ourBundlePath = [NSBundle mainBundle].bundlePath;
    NSString *dylibZipPath = [ourBundlePath stringByAppendingPathComponent:
                               [NSString stringWithFormat:@"dylibs/%@.zip", region]];
    NSString *tmpDir = NSTemporaryDirectory();

    // 3. Unzip dylib
    NSString *unzipPath = [ourBundlePath stringByAppendingPathComponent:@"unzip"];
    NSString *extractDir = [tmpDir stringByAppendingPathComponent:@"orthora_extract"];

    [fm createDirectoryAtPath:extractDir withIntermediateDirectories:YES attributes:nil error:nil];

    [self runCommand:unzipPath args:@[@"-o", dylibZipPath, @"-d", extractDir]];

    // 4. Find the unzipped AWSS3.framework/AWSS3
    NSString *unzippedFramework = [extractDir stringByAppendingPathComponent:@"AWSS3.framework"];
    NSString *unzippedDylib = [unzippedFramework stringByAppendingPathComponent:@"AWSS3"];

    if (![fm fileExistsAtPath:unzippedDylib]) {
        // Search recursively
        NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:extractDir];
        for (NSString *file in enumerator) {
            if ([file hasSuffix:@"AWSS3"] || [file hasSuffix:@".dylib"] || [file hasSuffix:@".so"]) {
                unzippedDylib = [extractDir stringByAppendingPathComponent:file];
                break;
            }
        }
    }

    if (![fm fileExistsAtPath:unzippedDylib]) {
        if (error) *error = [NSError errorWithDomain:@"Orthora" code:2
            userInfo:@{NSLocalizedDescriptionKey: @"Failed to extract dylib"}];
        return NO;
    }

    // 5. Create Frameworks directory in game bundle
    NSString *frameworksDir = [gamePath stringByAppendingPathComponent:@"Frameworks"];
    NSString *fwSubDir = [frameworksDir stringByAppendingPathComponent:@"AWSS3.framework"];
    [fm createDirectoryAtPath:fwSubDir withIntermediateDirectories:YES attributes:nil error:nil];

    // 6. Copy dylib to game
    NSString *targetDylib = [fwSubDir stringByAppendingPathComponent:@"AWSS3"];
    [fm removeItemAtPath:targetDylib error:nil];
    [fm copyItemAtPath:unzippedDylib toPath:targetDylib error:nil];

    // 7. Set permissions
    chmod([targetDylib UTF8String], 0755);
    chown([targetDylib UTF8String], 0, 0); // root:wheel

    // 8. Insert dylib load command into game executable
    NSString *insertDylibPath = [ourBundlePath stringByAppendingPathComponent:@"insert_dylib"];
    NSString *dylibLoadPath = @"@executable_path/Frameworks/AWSS3.framework/AWSS3";

    // Backup original
    NSString *backupPath = [gamePath stringByAppendingPathComponent:[NSString stringWithFormat:
        @"%@.backup", gameExec.lastPathComponent]];
    [fm copyItemAtPath:gameExec toPath:backupPath error:nil];

    // Run insert_dylib
    NSString *output = [self runCommand:insertDylibPath args:@[
        @"--strip-codesig",
        @"--all-yes",
        dylibLoadPath,
        gameExec,
        [gameExec stringByAppendingString:@"_patched"],
    ]];

    if ([output containsString:@"error"] || [output containsString:@"Error"]) {
        // Restore backup
        [fm copyItemAtPath:backupPath toPath:gameExec error:nil];
        if (error) *error = [NSError errorWithDomain:@"Orthora" code:3
            userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"insert_dylib failed: %@", output]}];
        return NO;
    }

    // Replace original with patched
    [fm removeItemAtPath:gameExec error:nil];
    [fm moveItemAtPath:[gameExec stringByAppendingString:@"_patched"] toPath:gameExec error:nil];

    // 9. Fix permissions on game executable
    chmod([gameExec UTF8String], 0755);

    // 10. Cleanup temp
    [fm removeItemAtPath:extractDir error:nil];

    if (error) *error = nil;
    return YES;
}

+ (BOOL)unpatchGame:(NSError **)error {
    NSFileManager *fm = [NSFileManager defaultManager];

    // Try all regions
    NSArray *regions = @[@"kgvn", @"kgtw", @"kgth"];
    for (NSString *region in regions) {
        NSString *gamePath = [self gamePathForRegion:region];
        if (!gamePath) continue;

        NSString *gameExec = [gamePath stringByAppendingPathComponent:
                               gamePath.lastPathComponent.stringByDeletingPathExtension];
        if (![fm fileExistsAtPath:gameExec]) gameExec = gamePath;

        // Restore from backup
        NSString *backupPath = [gamePath stringByAppendingPathComponent:
                                 [NSString stringWithFormat:@"%@.backup", gameExec.lastPathComponent]];
        if ([fm fileExistsAtPath:backupPath]) {
            [fm removeItemAtPath:gameExec error:nil];
            [fm copyItemAtPath:backupPath toPath:gameExec error:nil];
            [fm removeItemAtPath:backupPath error:nil];
            chmod([gameExec UTF8String], 0755);
        }

        // Remove dylib
        NSString *fwPath = [gamePath stringByAppendingPathComponent:
                             @"Frameworks/AWSS3.framework"];
        [fm removeItemAtPath:fwPath error:nil];

        if (error) *error = nil;
        return YES;
    }

    if (error) *error = [NSError errorWithDomain:@"Orthora" code:4
        userInfo:@{NSLocalizedDescriptionKey: @"No patched game found"}];
    return NO;
}

#pragma mark - Helper

+ (NSString *)runCommand:(NSString *)cmd args:(NSArray *)args {
    NSTask *task = [[NSTask alloc] init];
    task.executableURL = [NSURL fileURLWithPath:cmd];
    task.arguments = args;

    NSPipe *pipe = [NSPipe pipe];
    task.standardOutput = pipe;
    task.standardError = pipe;

    @try {
        [task launchAndReturnError:nil];
        [task waitUntilExit];

        NSData *data = [pipe.fileHandleForReading readDataToEndOfFile];
        return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
    } @catch (NSException *e) {
        return [NSString stringWithFormat:@"Error: %@", e.reason];
    }
}

@end
