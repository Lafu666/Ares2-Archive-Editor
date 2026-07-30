#!/usr/bin/env python3
"""Generate a minimal but valid Xcode project for DecryptEditor iOS app."""

import os
import uuid
import plistlib

PROJECT_DIR = os.path.dirname(os.path.abspath(__file__))
SRC_DIR = os.path.join(PROJECT_DIR, "DecryptEditor")
XCODE_DIR = os.path.join(PROJECT_DIR, "DecryptEditor.xcodeproj")
PBX_FILE = os.path.join(XCODE_DIR, "project.pbxproj")

PRODUCT_NAME = "DecryptEditor"
BUNDLE_ID = "com.ars.decrypt.ios"
SWIFT_VERSION = "5.0"
IOS_VERSION = "17.0"


def new_uid():
    return uuid.uuid4().hex.upper()


def source_files(root):
    files = []
    for dirpath, _, filenames in os.walk(root):
        for f in filenames:
            if f.endswith(".swift") or f.endswith(".plist"):
                rel = os.path.relpath(os.path.join(dirpath, f), PROJECT_DIR)
                files.append(rel)
    return sorted(files)


def build_pbx():
    uids = {"root": new_uid(), "mainGroup": new_uid(), "productGroup": new_uid(), "buildPhase_sources": new_uid(),
            "buildPhase_resources": new_uid(), "buildPhase_frameworks": new_uid(), "buildConfig_debug": new_uid(),
            "buildConfig_release": new_uid(), "configList_project": new_uid(), "configList_target": new_uid(),
            "nativeTarget": new_uid(), "productRef": new_uid(), "resources_build": new_uid()}

    uids["xcconfig"] = u"DEBUG" + uuid.uuid4().hex.upper()[:8]

    files = source_files(PROJECT_DIR)
    file_refs = {}
    build_file_refs = {}
    groups = {}

    for f in files:
        fid = new_uid()
        file_refs[f] = fid
        bfid = new_uid()
        build_file_refs[f] = bfid
        parent = os.path.dirname(f) or "."
        if parent not in groups:
            groups[parent] = new_uid()

    pbx = {
        "archiveVersion": 1,
        "classes": {},
        "objectVersion": 56,
        "objects": {
            uids["root"]: {
                "isa": "PBXProject",
                "attributes": {
                    "BuildIndependentTargetsInParallel": 1,
                    "LastSwiftUpdateCheck": 1540,
                    "LastUpgradeCheck": 1540,
                    "TargetAttributes": {uids["nativeTarget"]: {"CreatedOnToolsVersion": "15.4"}}
                },
                "buildConfigurationList": uids["configList_project"],
                "compatibilityVersion": "Xcode 14.0",
                "developmentRegion": "zh-Hans",
                "hasScannedForEncodings": 0,
                "knownRegions": ["en", "zh-Hans", "Base"],
                "mainGroup": uids["mainGroup"],
                "productRefGroup": uids["productGroup"],
                "projectDirPath": "",
                "projectRoot": "",
                "targets": [uids["nativeTarget"]],
            },
            uids["configList_project"]: {
                "isa": "XCConfigurationList",
                "buildConfigurations": [uids["buildConfig_debug"], uids["buildConfig_release"]],
                "defaultConfigurationIsVisible": 0,
                "defaultConfigurationName": "Release",
            },
            uids["configList_target"]: {
                "isa": "XCConfigurationList",
                "buildConfigurations": [uids["xcconfig"]],
                "defaultConfigurationIsVisible": 0,
                "defaultConfigurationName": "Release",
            },
            uids["buildConfig_debug"]: {
                "isa": "XCBuildConfiguration",
                "buildSettings": {
                    "ALWAYS_SEARCH_USER_PATHS": "NO",
                    "CLANG_ANALYZER_NONNULL": "YES",
                    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
                    "CLANG_ENABLE_MODULES": "YES",
                    "CLANG_ENABLE_OBJC_ARC": "YES",
                    "COPY_PHASE_STRIP": "NO",
                    "DEBUG_INFORMATION_FORMAT": "dwarf",
                    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
                    "ENABLE_TESTABILITY": "YES",
                    "GCC_DYNAMIC_NO_PIC": "NO",
                    "GCC_OPTIMIZATION_LEVEL": "0",
                    "GCC_PREPROCESSOR_DEFINITIONS": ["DEBUG=1", "$(inherited)"],
                    "IPHONEOS_DEPLOYMENT_TARGET": IOS_VERSION,
                    "MTL_ENABLE_DEBUG_INFO": "INCLUDE_SOURCE",
                    "ONLY_ACTIVE_ARCH": "YES",
                    "SDKROOT": "iphoneos",
                    "SWIFT_ACTIVE_COMPILATION_CONDITIONS": "DEBUG",
                    "SWIFT_OPTIMIZATION_LEVEL": "-Onone",
                },
                "name": "Debug",
            },
            uids["buildConfig_release"]: {
                "isa": "XCBuildConfiguration",
                "buildSettings": {
                    "ALWAYS_SEARCH_USER_PATHS": "NO",
                    "CLANG_ANALYZER_NONNULL": "YES",
                    "CLANG_CXX_LANGUAGE_STANDARD": "gnu++20",
                    "CLANG_ENABLE_MODULES": "YES",
                    "CLANG_ENABLE_OBJC_ARC": "YES",
                    "COPY_PHASE_STRIP": "NO",
                    "DEBUG_INFORMATION_FORMAT": "dwarf-with-dsym",
                    "ENABLE_NS_ASSERTIONS": "NO",
                    "ENABLE_STRICT_OBJC_MSGSEND": "YES",
                    "GCC_OPTIMIZATION_LEVEL": "s",
                    "IPHONEOS_DEPLOYMENT_TARGET": IOS_VERSION,
                    "MTL_ENABLE_DEBUG_INFO": "NO",
                    "SDKROOT": "iphoneos",
                    "SWIFT_COMPILATION_MODE": "wholemodule",
                    "SWIFT_OPTIMIZATION_LEVEL": "-O",
                    "VALIDATE_PRODUCT": "YES",
                },
                "name": "Release",
            },
            # Target-level xcconfig (used for both configurations)
            uids["xcconfig"]: {
                "isa": "XCBuildConfiguration",
                "buildSettings": {
                    "ASSETCATALOG_COMPILER_APPICON_NAME": "AppIcon",
                    "ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME": "AccentColor",
                    "CODE_SIGN_STYLE": "Manual",
                    "CODE_SIGNING_ALLOWED": "NO",
                    "CODE_SIGNING_REQUIRED": "NO",
                    "CURRENT_PROJECT_VERSION": "1",
                    "DEVELOPMENT_TEAM": "",
                    "GENERATE_INFOPLIST_FILE": "NO",
                    "INFOPLIST_FILE": "DecryptEditor/Info.plist",
                    "INFOPLIST_KEY_UIApplicationSceneManifest_Generation": "YES",
                    "INFOPLIST_KEY_UIApplicationSupportsIndirectInputEvents": "YES",
                    "INFOPLIST_KEY_UILaunchScreen_Generation": "YES",
                    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPad": "UIInterfaceOrientationPortrait_UIInterfaceOrientationPortraitUpsideDown_UIInterfaceOrientationLandscapeLeft_UIInterfaceOrientationLandscapeRight",
                    "INFOPLIST_KEY_UISupportedInterfaceOrientations_iPhone": "UIInterfaceOrientationPortrait",
                    "IPHONEOS_DEPLOYMENT_TARGET": IOS_VERSION,
                    "LD_RUNPATH_SEARCH_PATHS": ["$(inherited)", "@executable_path/Frameworks"],
                    "MARKETING_VERSION": "1.0",
                    "PRODUCT_BUNDLE_IDENTIFIER": BUNDLE_ID,
                    "PRODUCT_NAME": PRODUCT_NAME,
                    "SWIFT_EMIT_LOC_STRINGS": "YES",
                    "SWIFT_VERSION": SWIFT_VERSION,
                    "TARGETED_DEVICE_FAMILY": "1,2",
                },
                "name": "Release",
            },
            uids["mainGroup"]: {
                "isa": "PBXGroup",
                "children": [uids["productGroup"]],
                "sourceTree": "<group>",
            },
            uids["productGroup"]: {
                "isa": "PBXGroup",
                "children": [uids["productRef"]],
                "name": "Products",
                "sourceTree": "<group>",
            },
            uids["productRef"]: {
                "isa": "PBXFileReference",
                "explicitFileType": "wrapper.application",
                "includeInIndex": 0,
                "path": f"{PRODUCT_NAME}.app",
                "sourceTree": "BUILT_PRODUCTS_DIR",
            },
            uids["nativeTarget"]: {
                "isa": "PBXNativeTarget",
                "buildConfigurationList": uids["configList_target"],
                "buildPhases": [uids["buildPhase_sources"], uids["buildPhase_frameworks"], uids["buildPhase_resources"]],
                "buildRules": [],
                "dependencies": [],
                "name": PRODUCT_NAME,
                "productName": PRODUCT_NAME,
                "productReference": uids["productRef"],
                "productType": "com.apple.product-type.application",
            },
            uids["buildPhase_sources"]: {
                "isa": "PBXSourcesBuildPhase",
                "buildActionMask": 2147483647,
                "files": [],
                "runOnlyForDeploymentPostprocessing": 0,
            },
            uids["buildPhase_frameworks"]: {
                "isa": "PBXFrameworksBuildPhase",
                "buildActionMask": 2147483647,
                "files": [],
                "runOnlyForDeploymentPostprocessing": 0,
            },
            uids["buildPhase_resources"]: {
                "isa": "PBXResourcesBuildPhase",
                "buildActionMask": 2147483647,
                "files": [],
                "runOnlyForDeploymentPostprocessing": 0,
            },
        },
    }

    main_children = [uids["productGroup"]]
    for f in files:
        fid = file_refs[f]
        bfid = build_file_refs[f]
        parent = os.path.dirname(f) or "."
        parent_key = groups.get(parent) or uids["mainGroup"]

        pbx["objects"][fid] = {
            "isa": "PBXFileReference",
            "lastKnownFileType": "sourcecode.swift" if f.endswith(".swift") else "text.plist.xml",
            "path": os.path.basename(f),
            "sourceTree": "<group>",
        }

        if f.endswith(".plist"):
            pbx["objects"][bfid] = {"isa": "PBXBuildFile", "fileRef": fid}
            pbx["objects"][uids["buildPhase_resources"]]["files"].append(bfid)
        else:
            pbx["objects"][bfid] = {"isa": "PBXBuildFile", "fileRef": fid}
            pbx["objects"][uids["buildPhase_sources"]]["files"].append(bfid)

    # Build group hierarchy
    for dirpath, _, _ in os.walk(SRC_DIR):
        rel = os.path.relpath(dirpath, PROJECT_DIR)
        if rel == ".":
            continue
        gid = groups.get(rel, new_uid())
        if gid not in pbx["objects"]:
            parent = os.path.dirname(rel)
            parent_gid = groups.get(parent, uids["mainGroup"])
            pbx["objects"][gid] = {
                "isa": "PBXGroup",
                "children": [],
                "path": os.path.basename(rel),
                "sourceTree": "<group>",
            }
            if parent_gid not in pbx["objects"]:
                pbx["objects"][parent_gid] = {"isa": "PBXGroup", "children": [], "path": os.path.basename(parent), "sourceTree": "<group>"}
            pbx["objects"][parent_gid]["children"].append(gid)

    # Assign file refs to their parent groups
    for f in files:
        parent = os.path.dirname(f) or "."
        parent_gid = groups.get(parent, uids["mainGroup"])
        if parent_gid not in pbx["objects"]:
            pbx["objects"][parent_gid] = {"isa": "PBXGroup", "children": [], "path": os.path.basename(parent), "sourceTree": "<group>"}
        pbx["objects"][parent_gid]["children"].append(file_refs[f])

    return pbx


def main():
    os.makedirs(XCODE_DIR, exist_ok=True)
    pbx = build_pbx()

    content = plistlib.dumps(pbx, sort_keys=True)
    lines = content.decode("utf-8").splitlines()
    lines.insert(0, "// !$*UTF8*$!")
    # Fix plistlib output to proper pbxproj format
    result = "\n".join(lines)
    result = result.replace("<?xml version=\"1.0\" encoding=\"UTF-8\"?>", "")
    result = result.replace("<!DOCTYPE plist PUBLIC \"-//Apple//DTD PLIST 1.0//EN\" \"http://www.apple.com/DTDs/PropertyList-1.0.dtd\">", "")
    result = result.replace("<plist version=\"1.0\">", "")
    result = result.replace("</plist>", "")
    result = result.strip()

    with open(PBX_FILE, "w") as f:
        f.write(result + "\n")

    print(f"Generated: {PBX_FILE}")
    print(f"Source files: {len([f for f in source_files(PROJECT_DIR) if f.endswith('.swift')])}")


if __name__ == "__main__":
    main()
