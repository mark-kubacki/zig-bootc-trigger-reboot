const std = @import("std");

const targets: []const std.Target.Query = &.{
    .{ .cpu_arch = .x86_64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.x86.cpu.x86_64_v2 } },    // without AVX
    .{ .cpu_arch = .aarch64, .os_tag = .linux, .cpu_model = .{ .explicit = &std.Target.arm.cpu.cortex_a53 } },  // Radxa Zero, RPi 2W
    .{
        .cpu_arch = .riscv64,
        .os_tag = .linux,
        .cpu_model = .{ .explicit = &std.Target.riscv.cpu.baseline_rv64 }, // Contains .d for lp64d.
        .cpu_features_add = std.Target.riscv.featureSet(&[_]std.Target.riscv.Feature{ .rva23u64, .v }), // RVA23
    },
};

pub fn build(b: *std.Build) !void {
    b.install_path = b.build_root.join(b.allocator, &.{"release"}) catch unreachable;

    for (targets) |t| {
        const exe = b.addExecutable(.{
            .name = "check-bootc-and-reboot",
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/main.zig"),
                .target = b.resolveTargetQuery(t),
                .optimize = .ReleaseSmall,
                .single_threaded = true,
                .unwind_tables = .none,
            }),
        });
        exe.stack_size = 0; // Go with the OS’ default. Saves 2 syscalls to make it 8 MiB.

        const target_output = b.addInstallArtifact(exe, .{
            .dest_dir = .{
                .override = .{
                    .custom = try t.zigTriple(b.allocator),
                },
            },
        });

        b.getInstallStep().dependOn(&target_output.step);
    }
}
