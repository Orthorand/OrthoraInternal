#import "UnityTypes.h"
#import <Foundation/Foundation.h>
#import <mach-o/dyld.h>
#import <mach-o/getsect.h>

bool GetMachOInfo(const char *image_name, MachOInfo *out) {
    if (!image_name || !out) return false;
    memset(out, 0, sizeof(MachOInfo));

    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name) continue;

        // Match by suffix (e.g., "libil2cpp" or full path)
        if (!strstr(name, image_name)) continue;

        out->slide = _dyld_get_image_vmaddr_slide(i);
        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        out->base = (uint64_t)header;

        const struct segment_command_64 *seg;
        uint64_t fileoff = 0;

        // __TEXT
        seg = getsegbynamefromheader_64(header, "__TEXT");
        if (seg) {
            out->text_addr = out->base + seg->vmaddr - out->slide;
            out->text_size = seg->vmsize;
        }

        // __DATA
        seg = getsegbynamefromheader_64(header, "__DATA");
        if (seg) {
            out->data_addr = out->base + seg->vmaddr - out->slide;
            out->data_size = seg->vmsize;
        }

        // __DATA_CONST
        seg = getsegbynamefromheader_64(header, "__DATA_CONST");
        if (seg) {
            out->data_addr = out->base + seg->vmaddr - out->slide;
            out->data_size += seg->vmsize;
        }

        // __LINKEDIT
        seg = getsegbynamefromheader_64(header, "__LINKEDIT");
        if (seg) {
            out->linkedit_addr = out->base + seg->vmaddr - out->slide;
            out->linkedit_size = seg->vmsize;
        }

        return true;
    }

    return false;
}

uint64_t FindSymbolInImage(const char *image_name, const char *symbol_name) {
    if (!image_name || !symbol_name) return 0;

    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, image_name)) continue;

        const struct mach_header_64 *header = (const struct mach_header_64 *)_dyld_get_image_header(i);
        int64_t slide = _dyld_get_image_vmaddr_slide(i);

        Dl_info info;
        if (dladdr((void *)header, &info)) {
            // Search via getsectdata for __nl_symbol_ptr / __got
            unsigned long size;
            void *ptr = getsectiondata(header, "__DATA", "__nl_symbol_ptr", &size);
            if (!ptr) ptr = getsectiondata(header, "__DATA_CONST", "__got", &size);

            // Fallback: use dlsym
            void *sym = dlsym((void *)RTLD_DEFAULT, symbol_name);
            if (sym) return (uint64_t)sym;
        }
    }

    return 0;
}

// Scan memory for a pattern (used to find IL2CPP registrations)
uint64_t ScanMemoryPattern(const uint8_t *start, size_t size,
                           const uint8_t *pattern, size_t pattern_len) {
    if (!start || !pattern || pattern_len == 0 || size < pattern_len) return 0;

    for (size_t i = 0; i <= size - pattern_len; i += 8) { // 8-byte aligned
        if (memcmp(start + i, pattern, pattern_len) == 0) {
            return (uint64_t)(start + i);
        }
    }
    return 0;
}
