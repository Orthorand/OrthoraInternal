#import "IL2CPPDump.h"
#import "UnityTypes.h"
#import <Foundation/Foundation.h>
#import <dlfcn.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>
#import <sys/stat.h>
#import <fcntl.h>
#import <unistd.h>

#define LOGI(fmt, ...) NSLog(@"[Orthora-Dump] " fmt, ##__VA_ARGS__)
#define LOGE(fmt, ...) NSLog(@"[Orthora-Dump][ERR] " fmt, ##__VA_ARGS__)

// ========== Metadata deobfuscation (same algorithm as Android) ==========
static uint32_t xor_subtract_u32(uint32_t value, uint32_t sub, uint32_t key) {
    return ((value - sub) ^ key);
}

static bool deobfuscate_metadata(void *data, size_t size) {
    if (!data || size < 0x100) return false;

    uint32_t *header = (uint32_t *)data;
    if (header[0] != 0xEAB11BAF || header[1] < 29) return false;

    uint32_t input[64], output[64] = {0};
    memcpy(input, header, sizeof(input));

    output[0] = input[0];
    output[1] = input[1];
    for (int i = 50; i < 64; i++) output[i] = input[i];

    output[4] = input[2] ^ 0x00A8C72D;
    output[5] = input[3] ^ 0x00A8C72D;
    output[8] = xor_subtract_u32(input[4], 3, 0x00A8C72E);
    output[9] = xor_subtract_u32(input[5], 7, 0x00A8C72F);
    output[12] = xor_subtract_u32(input[6], 6, 0x00A8C72F);
    output[13] = xor_subtract_u32(input[7], 14, 0x00A8C731);
    output[16] = xor_subtract_u32(input[8], 9, 0x00A8C730);
    output[17] = xor_subtract_u32(input[9], 21, 0x00A8C733);
    output[20] = xor_subtract_u32(input[10], 12, 0x00A8C731);
    output[21] = xor_subtract_u32(input[11], 28, 0x00A8C735);
    output[6] = xor_subtract_u32(input[12], 15, 0x00A8C732);
    output[7] = xor_subtract_u32(input[13], 35, 0x00A8C737);
    output[10] = xor_subtract_u32(input[14], 18, 0x00A8C733);
    output[11] = xor_subtract_u32(input[15], 42, 0x00A8C739);
    output[14] = xor_subtract_u32(input[16], 21, 0x00A8C734);
    output[15] = xor_subtract_u32(input[17], 49, 0x00A8C73B);
    output[18] = xor_subtract_u32(input[18], 24, 0x00A8C735);
    output[19] = xor_subtract_u32(input[19], 56, 0x00A8C73D);
    output[22] = xor_subtract_u32(input[20], 27, 0x00A8C736);
    output[23] = xor_subtract_u32(input[21], 63, 0x00A8C73F);
    output[2] = xor_subtract_u32(input[22], 30, 0x00A8C737);
    output[3] = xor_subtract_u32(input[23], 70, 0x00A8C741);
    output[48] = xor_subtract_u32(input[24], 33, 0x00A8C738);
    output[49] = xor_subtract_u32(input[25], 77, 0x00A8C743);
    output[46] = xor_subtract_u32(input[26], 36, 0x00A8C739);
    output[47] = xor_subtract_u32(input[27], 84, 0x00A8C745);
    output[44] = xor_subtract_u32(input[28], 39, 0x00A8C73A);
    output[45] = xor_subtract_u32(input[29], 91, 0x00A8C747);
    output[42] = xor_subtract_u32(input[30], 42, 0x00A8C73B);
    output[43] = xor_subtract_u32(input[31], 98, 0x00A8C749);
    output[24] = xor_subtract_u32(input[32], 45, 0x00A8C73C);
    output[25] = xor_subtract_u32(input[33], 105, 0x00A8C74B);
    output[28] = xor_subtract_u32(input[34], 48, 0x00A8C73D);
    output[29] = xor_subtract_u32(input[35], 112, 0x00A8C74D);
    output[32] = xor_subtract_u32(input[36], 51, 0x00A8C73E);
    output[33] = xor_subtract_u32(input[37], 119, 0x00A8C74F);
    output[36] = xor_subtract_u32(input[38], 54, 0x00A8C73F);
    output[37] = xor_subtract_u32(input[39], 126, 0x00A8C751);
    output[40] = xor_subtract_u32(input[40], 57, 0x00A8C740);
    output[41] = xor_subtract_u32(input[41], 133, 0x00A8C753);
    output[26] = xor_subtract_u32(input[42], 60, 0x00A8C741);
    output[27] = xor_subtract_u32(input[43], 140, 0x00A8C755);
    output[30] = xor_subtract_u32(input[44], 63, 0x00A8C742);
    output[31] = xor_subtract_u32(input[45], 147, 0x00A8C757);
    output[34] = xor_subtract_u32(input[46], 66, 0x00A8C743);
    output[35] = xor_subtract_u32(input[47], 154, 0x00A8C759);
    output[38] = xor_subtract_u32(input[48], 69, 0x00A8C744);
    output[39] = xor_subtract_u32(input[49], 161, 0x00A8C75B);

    memcpy(header, output, sizeof(output));
    header[0] = 0xFAB11BAF;
    return true;
}

// ========== Find metadata path on iOS ==========
static NSString *FindMetadataPath(void) {
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *bundlePath = [[NSBundle mainBundle] bundlePath];

    // Standard Unity iOS metadata locations
    NSArray *paths = @[
        [bundlePath stringByAppendingPathComponent:@"Data/il2cpp/Metadata/global-metadata.dat"],
        [bundlePath stringByAppendingPathComponent:@"Data/Metadata/global-metadata.dat"],
        [bundlePath stringByAppendingPathComponent:@"Metadata/global-metadata.dat"],
        [bundlePath stringByAppendingPathComponent:@"global-metadata.dat"],
    ];

    for (NSString *path in paths) {
        if ([fm fileExistsAtPath:path]) return path;
    }

    // Search inside .app directory
    NSDirectoryEnumerator *enumerator = [fm enumeratorAtPath:bundlePath];
    for (NSString *file in enumerator) {
        if ([file hasSuffix:@"global-metadata.dat"]) {
            return [bundlePath stringByAppendingPathComponent:file];
        }
    }

    return nil;
}

// ========== File-based metadata dump (same as Android) ==========
static const char *metadata_string(uint8_t *meta, const uint32_t *hdr, uint32_t index) {
    if (!meta || !hdr) return NULL;
    uint32_t stringOffset = hdr[6];
    uint32_t stringSize = hdr[7];
    if (index >= stringSize) return NULL;
    return (const char *)(meta + stringOffset + index);
}

void IL2CPPDumpStart(void) {
    @autoreleasepool {
        LOGI(@"Looking for global-metadata.dat...");

        NSString *metaPath = FindMetadataPath();
        if (!metaPath) {
            LOGE(@"Cannot find global-metadata.dat");
            return;
        }
        LOGI(@"Found metadata: %@", metaPath);

        // Load file
        NSData *metaData = [NSData dataWithContentsOfFile:metaPath];
        if (!metaData || metaData.length < 0x100) {
            LOGE(@"Invalid metadata file");
            return;
        }

        // mutable copy for deobfuscation
        NSMutableData *mutableMeta = [metaData mutableCopy];
        uint8_t *metaBytes = (uint8_t *)mutableMeta.mutableBytes;

        if (!deobfuscate_metadata(metaBytes, mutableMeta.length)) {
            LOGE(@"Metadata deobfuscation failed");
            return;
        }

        const uint32_t *hdr = (const uint32_t *)metaBytes;
        if (hdr[0] != 0xFAB11BAF || hdr[1] < 29) {
            LOGE(@"Invalid metadata header after deobfuscation");
            return;
        }
        LOGI(@"Metadata deobfuscated OK (version %u)", hdr[1]);

        // ===== Parse and dump to file =====
        NSString *docDir = [NSSearchPathForDirectoriesInDomains(
            NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        NSString *dumpPath = [docDir stringByAppendingPathComponent:@"il2cpp_dump.cs"];
        LOGI(@"Writing dump to: %@", dumpPath);

        NSMutableString *dump = [NSMutableString string];
        [dump appendString:@"// ========== IL2CPP DUMP (iOS) ==========\n"];
        [dump appendFormat:@"// Generated: %s\n", __DATE__];
        [dump appendFormat:@"// Bundle: %@\n\n", [[NSBundle mainBundle] bundleIdentifier]];

        uint32_t imagesOff  = hdr[42];
        uint32_t imagesSize = hdr[43];
        uint32_t typesOff   = hdr[40];
        uint32_t typesSize  = hdr[41];
        uint32_t methodsOff = hdr[12];
        uint32_t methodsSize = hdr[13];
        uint32_t fieldsOff  = hdr[24];
        uint32_t fieldsSize = hdr[25];

        Il2CppImageDefinition *images =
            (Il2CppImageDefinition *)(metaBytes + imagesOff);
        Il2CppTypeDefinition *types =
            (Il2CppTypeDefinition *)(metaBytes + typesOff);
        Il2CppMethodDefinition *methods =
            (Il2CppMethodDefinition *)(metaBytes + methodsOff);
        Il2CppFieldDefinition *fields =
            (Il2CppFieldDefinition *)(metaBytes + fieldsOff);

        int imageCount = imagesSize / sizeof(Il2CppImageDefinition);
        int typeTotal  = typesSize / sizeof(Il2CppTypeDefinition);
        int methodTotal = methodsSize / sizeof(Il2CppMethodDefinition);
        int fieldTotal  = fieldsSize / sizeof(Il2CppFieldDefinition);

        for (int i = 0; i < imageCount; i++) {
            const char *imgName = metadata_string(metaBytes, hdr, images[i].nameIndex);
            if (!imgName || imgName[0] == 0) continue;

            [dump appendFormat:@"namespace %s\n{\n", imgName];

            int typeStart = images[i].typeStart;
            int typeCount = images[i].typeCount;

            for (int t = typeStart; t < typeStart + typeCount && t < typeTotal; t++) {
                const char *typeName = metadata_string(metaBytes, hdr, types[t].nameIndex);
                if (!typeName) continue;

                const char *ns = metadata_string(metaBytes, hdr, types[t].namespaceIndex);
                [dump appendFormat:@"\n    // Namespace: %s\n", ns ? ns : "<global>"];
                [dump appendFormat:@"    public class %s // TypeDefIndex: %d\n    {\n",
                 typeName, t];

                // Fields
                int fStart = types[t].fieldStart;
                int fCount = types[t].field_count;
                if (fCount > 0) {
                    [dump appendString:@"        // Fields\n"];
                    for (int f = fStart; f < fStart + fCount && f < fieldTotal; f++) {
                        const char *fieldName = metadata_string(metaBytes, hdr, fields[f].nameIndex);
                        if (fieldName)
                            [dump appendFormat:@"        public int %s;\n", fieldName];
                    }
                    [dump appendString:@"\n"];
                }

                // Methods
                int mStart = types[t].methodStart;
                int mCount = types[t].method_count;
                if (mCount > 0) {
                    [dump appendString:@"        // Methods\n"];
                    for (int m = mStart; m < mStart + mCount && m < methodTotal; m++) {
                        const char *methodName = metadata_string(metaBytes, hdr, methods[m].nameIndex);
                        if (methodName) {
                            [dump appendFormat:@"        public void %s(", methodName];
                            int paramCount = methods[m].parameterCount;
                            for (int p = 0; p < paramCount; p++) {
                                if (p > 0) [dump appendString:@", "];
                                [dump appendFormat:@"P%d", p];
                            }
                            [dump appendString:@") { }\n"];
                        }
                    }
                }

                [dump appendString:@"    }\n"];
            }

            [dump appendString:@"}\n\n"];
        }

        [dump writeToFile:dumpPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
        LOGI(@"Dump complete! -> %@ (%lu bytes)", dumpPath, (unsigned long)dump.length);
    }
}
