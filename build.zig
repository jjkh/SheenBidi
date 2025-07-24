const std = @import("std");

// const version = std.SemanticVersion.parse(@import("build.zig.zon").version) catch unreachable;
const version = std.SemanticVersion{ .major = 2, .minor = 9, .patch = 0 };

pub fn build(b: *std.Build) void {
    const upstream = b.dependency("SheenBidi", .{});
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const build_tests = b.option(
        bool,
        "build-tests",
        "Build the test executable (default: false)",
    ) orelse false;
    const build_generator = b.option(
        bool,
        "build-generator",
        "Build the Unicode data generator tool (default: false)",
    ) orelse false;

    const unity_build = b.option(
        bool,
        "unity",
        "Build with a single unity source file (default: true)",
    ) orelse !build_tests;
    const linkage = b.option(
        std.builtin.LinkMode,
        "linkage",
        "Whether to build SheenBidi as a static or dynamic library (default: static)",
    ) orelse .static;
    const dll_mode = linkage == .dynamic and target.result.os.tag == .windows;

    if (build_tests and unity_build) {
        std.log.err("cannot build tests with unity build enabled", .{});
        b.invalid_user_input = true;
        return;
    }
    if (build_tests and dll_mode) {
        std.log.err("cannot build tests when building Windows DLL", .{});
        b.invalid_user_input = true;
        return;
    }

    const lib = b.addLibrary(.{
        .name = "SheenBidi",
        .linkage = linkage,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
        .version = version,
    });

    const root_dir = upstream.path("");
    const src_dir = upstream.path("Source");
    const include_dir = upstream.path("Headers");
    const tools_dir = upstream.path("Tools");
    const tests_dir = upstream.path("Tests");

    const c_flags = &.{
        if (unity_build) "-DSB_CONFIG_UNITY" else "",
        if (dll_mode) "-DSB_CONFIG_DLL_EXPORT" else "",
    };
    lib.addCSourceFiles(.{
        .root = src_dir,
        .files = if (unity_build) unity_sources else sources,
        .flags = c_flags,
    });
    lib.addIncludePath(include_dir);
    for (sheenbidi_headers) |header|
        lib.installHeader(include_dir.path(b, header), header);

    b.installArtifact(lib);

    // parser required for tests and generator
    const parser_root = tools_dir.path(b, "Parser");
    const parser_lib = b.addLibrary(.{
        .name = "sheenbidi_parser",
        .linkage = .static,
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .link_libcpp = true,
        }),
    });
    parser_lib.addCSourceFiles(.{
        .root = parser_root,
        .files = parser_sources,
        .flags = cpp_flags,
    });
    parser_lib.addIncludePath(parser_root);

    if (build_tests) {
        const test_exe = b.addExecutable(.{
            .name = "sheenbidi_tests",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        test_exe.linkLibrary(parser_lib);
        test_exe.linkLibrary(lib);

        test_exe.addCSourceFiles(.{
            .root = tests_dir,
            .files = test_sources,
            .flags = cpp_flags,
        });
        test_exe.addIncludePath(root_dir);
        test_exe.addIncludePath(include_dir);
        test_exe.addIncludePath(tools_dir);

        b.installArtifact(test_exe);
    }

    if (build_generator) {
        const generator_root = tools_dir.path(b, "Generator");
        const generator_exe = b.addExecutable(.{
            .name = "sheenbidi_generator",
            .root_module = b.createModule(.{
                .target = target,
                .optimize = optimize,
            }),
        });

        generator_exe.linkLibrary(parser_lib);
        generator_exe.addCSourceFiles(.{
            .root = generator_root,
            .files = generator_sources,
            .flags = cpp_flags,
        });
        generator_exe.addIncludePath(root_dir);
        generator_exe.addIncludePath(include_dir);
        generator_exe.addIncludePath(tools_dir);

        b.installArtifact(generator_exe);
    }

    if (build_generator or build_tests) {
        b.installDirectory(.{
            .source_dir = upstream.path("Tools/Unicode"),
            .install_dir = .bin,
            .install_subdir = "UnicodeData",
        });
    }
}

const cpp_flags: []const []const u8 = &.{"-std=c++14"};

const sheenbidi_headers: []const []const u8 = &.{
    "SheenBidi/SBAlgorithm.h",
    "SheenBidi/SBBase.h",
    "SheenBidi/SBBidiType.h",
    "SheenBidi/SBCodepoint.h",
    "SheenBidi/SBCodepointSequence.h",
    "SheenBidi/SBGeneralCategory.h",
    "SheenBidi/SBLine.h",
    "SheenBidi/SBMirrorLocator.h",
    "SheenBidi/SBParagraph.h",
    "SheenBidi/SBRun.h",
    "SheenBidi/SBScript.h",
    "SheenBidi/SBScriptLocator.h",
    "SheenBidi/SBVersion.h",
    "SheenBidi/SheenBidi.h",
};

const unity_sources: []const []const u8 = &.{"SheenBidi.c"};

const sources: []const []const u8 = &.{
    "BidiChain.c",
    "BidiTypeLookup.c",
    "BracketQueue.c",
    "GeneralCategoryLookup.c",
    "IsolatingRun.c",
    "LevelRun.c",
    "Object.c",
    "PairingLookup.c",
    "RunQueue.c",
    "SBAlgorithm.c",
    "SBBase.c",
    "SBCodepoint.c",
    "SBCodepointSequence.c",
    "SBLine.c",
    "SBLog.c",
    "SBMirrorLocator.c",
    "SBParagraph.c",
    "SBScriptLocator.c",
    "ScriptLookup.c",
    "ScriptStack.c",
    "StatusStack.c",
};

const parser_sources: []const []const u8 = &.{
    "BidiBrackets.cpp",
    "BidiCharacterTest.cpp",
    "BidiMirroring.cpp",
    "BidiTest.cpp",
    "DataFile.cpp",
    "DerivedBidiClass.cpp",
    "DerivedCoreProperties.cpp",
    "DerivedGeneralCategory.cpp",
    "PropertyValueAliases.cpp",
    "PropList.cpp",
    "Scripts.cpp",
    "UnicodeData.cpp",
    "UnicodeVersion.cpp",
};

const generator_sources: []const []const u8 = &.{
    "Utilities/ArrayBuilder.cpp",
    "Utilities/Converter.cpp",
    "Utilities/FileBuilder.cpp",
    "Utilities/Math.cpp",
    "Utilities/StreamBuilder.cpp",
    "Utilities/TextBuilder.cpp",
    "BidiTypeLookupGenerator.cpp",
    "GeneralCategoryLookupGenerator.cpp",
    "main.cpp",
    "PairingLookupGenerator.cpp",
    "ScriptLookupGenerator.cpp",
};

const test_sources: []const []const u8 = &.{
    "Utilities/Convert.cpp",
    "AlgorithmTests.cpp",
    "BidiTypeLookupTests.cpp",
    "BracketLookupTests.cpp",
    "CodepointSequenceTests.cpp",
    "CodepointTests.cpp",
    "GeneralCategoryLookupTests.cpp",
    "MirrorLookupTests.cpp",
    "RunQueueTests.cpp",
    "ScriptLocatorTests.cpp",
    "ScriptLookupTests.cpp",
    "ScriptTests.cpp",
    "main.cpp",
};
