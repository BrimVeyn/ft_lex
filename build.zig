const std = @import("std");
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
const GeneratedFile = std.Build.GeneratedFile;

const liblPath: []const u8 = "src/libl/libl.a";

fn fileExist(path: []const u8) bool {
    std.fs.cwd().access(path, .{}) catch return false;
    return true;
}

fn ensureLiblIsBuilt(self: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = self; _ = options;
    if (!fileExist(liblPath)) {
        std.log.info("usage: zig build libl", .{});
        @panic("You must build the libl before running tests");
    }
}

fn buildLibl(self: *std.Build.Step, options: std.Build.Step.MakeOptions) anyerror!void {
    _ = self; _ = options;

    var child = std.process.Child.init(&[_][]const u8{
        "make", "-C", "src/libl",
    }, std.heap.page_allocator);

    child.stdin_behavior = .Ignore;
    child.stdout_behavior = .Ignore;
    child.stderr_behavior = .Ignore;

    const term = try child.spawnAndWait();
    std.debug.assert(term.Exited == 0);
}

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "ft_lex",
        .root_module = exe_mod,
    });
    exe.linkLibC();

    b.installArtifact(exe);
    
    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const libl_step = b.step("libl", "Build libl static library");
    libl_step.makeFn = buildLibl;

    const ensure_libl_is_built = b.addRunArtifact(exe_unit_tests);
    ensure_libl_is_built.step.makeFn = ensureLiblIsBuilt;

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&ensure_libl_is_built.step);
    test_step.dependOn(&run_exe_unit_tests.step);
}

