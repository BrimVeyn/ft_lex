const std = @import("std");
const Compile = std.Build.Step.Compile;
const LazyPath = std.Build.LazyPath;
const GeneratedFile = std.Build.GeneratedFile;

pub fn getEmittedDocs(self: *Compile) LazyPath {
    return self.getEmittedFileGeneric(&self.generated_docs);
}
fn getEmittedFileGeneric(self: *Compile, output_file: *?*GeneratedFile) LazyPath {
    if (output_file.*) |g| {
        return .{ .generated = g };
    }
    const arena = self.step.owner.allocator;
    const generated_file = arena.create(GeneratedFile) catch @panic("OOM");
    generated_file.* = .{ .step = &self.step };
    output_file.* = generated_file;
    return .{ .generated = generated_file };
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
    
    b.installDirectory(.{
        .source_dir = exe.getEmittedDocs(),
        .install_dir = .prefix,
        .install_subdir = "docs",
    });


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

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}

