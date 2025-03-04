const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "revisit",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Expat library
    const expat_dep = b.dependency("expat", .{
        .target = target,
        .optimize = optimize,
    });
    const expat = b.addStaticLibrary(.{
        .name = "expat",
        .target = target,
        .optimize = optimize,
    });
    expat.addCSourceFiles(.{
        .root = expat_dep.path("lib/"),
        .files = &.{
            "xmlparse.c",
            "xmlrole.c",
            "xmltok.c",
            "xmltok_impl.c",
            "xmltok_ns.c",
        },
    });
    expat.addIncludePath(expat_dep.path(""));
    expat.linkLibC();

    // ZLib
    const zlib_dep = b.dependency("zlib", .{
        .target = target,
        .optimize = optimize,
    });

    // Minizip (dependes on zlib)
    const minizip_dep = b.dependency("minizip", .{
        .target = target,
        .optimize = optimize,
    });
    const minizip = b.addStaticLibrary(.{
        .name = "minizip",
        .target = target,
        .optimize = optimize,
    });
    minizip.addCSourceFiles(.{
        .root = minizip_dep.path("contrib/minizip/"),
        .files = &.{
            "unzip.c",
            "zip.c",
            "ioapi.c",
        },
        .flags = &.{
            "-DHAVE_SYS_TYPES_H",
            "-DHAVE_STDINT_H",
            "-DHAVE_STDDEF_H",
            "-DZ_HAVE_UNISTD_H",
        },
    });
    minizip.addIncludePath(minizip_dep.path(""));
    minizip.installHeadersDirectory(minizip_dep.path(""), "", .{
        .include_extensions = &.{
            "zconf.h",
            "zlib.h",
        },
    });
    minizip.linkLibrary(zlib_dep.artifact("z"));
    minizip.linkLibC();

    // XLSXIO Library
    const xlsxio_dep = b.dependency("xlsxio", .{
        .target = target,
        .optimize = optimize,
    });
    const xlsxio = b.addStaticLibrary(.{
        .name = "xlsxio",
        .target = target,
        .optimize = optimize,
    });
    xlsxio.addCSourceFiles(.{
        .root = xlsxio_dep.path("lib/"),
        .files = &.{
            "xlsxio_read.c",
            "xlsxio_write.c",
            "xlsxio_read_sharedstrings.c",
        },
    });
    xlsxio.root_module.addCMacro("USE_MINIZIP", "");
    xlsxio.addIncludePath(xlsxio_dep.path("include/"));
    xlsxio.addIncludePath(expat_dep.path("lib/"));
    xlsxio.addIncludePath(minizip_dep.path("contrib/"));
    xlsxio.linkLibC();
    xlsxio.linkLibrary(expat);
    xlsxio.linkLibrary(minizip);

    // LibXLS Library
    const libxls_dep = b.dependency("libxls", .{
        .target = target,
        .optimize = optimize,
    });
    const libxls = b.addStaticLibrary(.{
        .name = "libxls",
        .target = target,
        .optimize = optimize,
    });
    libxls.addCSourceFiles(.{
        .root = libxls_dep.path("src"),
        .files = &.{
            "xls.c",
            "locale.c",
            "endian.c",
            "ole.c",
            "xlstool.c",
        },
    });
    libxls.addIncludePath(libxls_dep.path("include/"));
    libxls.addConfigHeader(b.addConfigHeader(.{}, .{}));
    libxls.root_module.addCMacro("PACKAGE_VERSION", "\"1.6.3\"");
    libxls.linkLibC();

    // Add the libraries to the exe
    exe.addIncludePath(xlsxio_dep.path("include/"));
    exe.addIncludePath(libxls_dep.path("include/"));
    exe.linkLibrary(xlsxio);
    exe.linkLibrary(libxls);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
