#pragma once

#include <stdint.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <mach-o/fat.h>

#ifdef __cplusplus
extern "C" {
#endif

// ========== IL2CPP Metadata structures (shared with Android) ==========

typedef struct {
    uint32_t nameIndex;
    int32_t assemblyIndex;
    int32_t typeStart;
    uint32_t typeCount;
    int32_t exportedTypeStart;
    uint32_t exportedTypeCount;
    int32_t entryPointIndex;
    uint32_t token;
    int32_t customAttributeStart;
    uint32_t customAttributeCount;
} Il2CppImageDefinition;

typedef struct {
    uint32_t nameIndex;
    uint32_t namespaceIndex;
    int32_t byvalTypeIndex;
    int32_t declaringTypeIndex;
    int32_t parentIndex;
    int32_t elementTypeIndex;
    int32_t genericContainerIndex;
    uint32_t flags;
    int32_t fieldStart;
    int32_t methodStart;
    int32_t eventStart;
    int32_t propertyStart;
    int32_t nestedTypesStart;
    int32_t interfacesStart;
    int32_t vtableStart;
    int32_t interfaceOffsetsStart;
    uint16_t method_count;
    uint16_t property_count;
    uint16_t field_count;
    uint16_t event_count;
    uint16_t nested_type_count;
    uint16_t vtable_count;
    uint16_t interfaces_count;
    uint16_t interface_offsets_count;
    uint32_t bitfield;
    uint32_t token;
} Il2CppTypeDefinition;

typedef struct {
    uint32_t nameIndex;
    int32_t declaringType;
    int32_t returnType;
    int32_t parameterStart;
    int32_t genericContainerIndex;
    uint32_t token;
    uint16_t flags;
    uint16_t iflags;
    uint16_t slot;
    uint16_t parameterCount;
} Il2CppMethodDefinition;

typedef struct {
    uint32_t nameIndex;
    int32_t typeIndex;
    uint32_t token;
} Il2CppFieldDefinition;

typedef struct {
    uint32_t nameIndex;
    int32_t getIndex;
    int32_t setIndex;
    uint32_t token;
} Il2CppPropertyDefinition;

typedef struct {
    uint64_t reversePInvokeWrapperCount;
    uint64_t reversePInvokeWrappers;
    uint64_t genericMethodPointersCount;
    uint64_t genericMethodPointers;
    uint64_t genericAdjustorThunks;
    uint64_t invokerPointersCount;
    uint64_t invokerPointers;
    uint64_t unresolvedVirtualCallCount;
    uint64_t unresolvedVirtualCallPointers;
    uint64_t interopDataCount;
    uint64_t interopData;
    uint64_t windowsRuntimeFactoryCount;
    uint64_t windowsRuntimeFactoryTable;
    uint64_t codeGenModulesCount;
    uint64_t codeGenModules;
} Il2CppCodeRegistration;

typedef struct {
    uint64_t moduleName;
    int64_t methodPointerCount;
    uint64_t methodPointers;
    int64_t adjustorThunkCount;
    uint64_t adjustorThunks;
    uint64_t invokerIndices;
    uint64_t reversePInvokeWrapperCount;
    uint64_t reversePInvokeWrapperIndices;
    int64_t rgctxRangesCount;
    uint64_t rgctxRanges;
    int64_t rgctxsCount;
    uint64_t rgctxs;
    uint64_t debuggerMetadata;
    uint64_t moduleInitializer;
    uint64_t staticConstructorTypeIndices;
    uint64_t metadataRegistration;
    uint64_t codeRegistration;
} Il2CppCodeGenModule;

typedef struct {
    int64_t genericClassesCount;
    uint64_t genericClasses;
    int64_t genericInstsCount;
    uint64_t genericInsts;
    int64_t genericMethodTableCount;
    uint64_t genericMethodTable;
    int64_t typesCount;
    uint64_t types;
    int64_t methodSpecsCount;
    uint64_t methodSpecs;
    int64_t fieldOffsetsCount;
    uint64_t fieldOffsets;
    int64_t typeDefinitionsSizesCount;
    uint64_t typeDefinitionsSizes;
    uint64_t metadataUsagesCount;
    uint64_t metadataUsages;
} Il2CppMetadataRegistration;

// ========== iOS-specific Mach-O helpers ==========

typedef struct {
    uint64_t slide;
    uint64_t base;
    uint64_t text_addr;
    uint64_t text_size;
    uint64_t data_addr;
    uint64_t data_size;
    uint64_t linkedit_addr;
    uint64_t linkedit_size;
} MachOInfo;

bool GetMachOInfo(const char *image_name, MachOInfo *out);
uint64_t FindSymbolInImage(const char *image_name, const char *symbol_name);

#ifdef __cplusplus
}
#endif
