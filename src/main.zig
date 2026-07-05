const std = @import("std");
pub const panic = @import("std").debug.no_panic;

pub const std_options: std.Options = .{
    .networking = false,
};

pub fn main(init: std.process.Init) u8 {
    const mem = init.arena.allocator();
    defer _ = init.arena.deinit();

    const output = std.process.run(mem, init.io, .{
        .argv = &.{ "/usr/bin/bootc", "status", "--json" },
    }) catch {
        return 5; // ExitNotInstalled
    };

    const need_reboot = hasBootcAnythingStaged(mem, output.stdout) catch {
        std.Io.File.stderr().writeStreamingAll(init.io, output.stderr) catch {};
        return 6; // ExitNotConfigured
    };
    if (!need_reboot) {
        std.Io.File.stdout().writeStreamingAll(init.io, "Nothing staged") catch {};
        return 0; // ExitOK
    }

    std.process.replace(init.io, .{
        .argv = &.{ "/usr/bin/systemctl", "reboot" },
    }) catch {
        std.Io.File.stdout().writeStreamingAll(init.io, "Needs a reboot") catch {};
        return 1; // ExitFailure
    };
}

// Returns true based on the output of `bootc --json`.
fn hasBootcAnythingStaged(mem: std.mem.Allocator, output: []const u8) !bool {
    const BootcStatus = struct {};
    const BootcOutput = struct {
        status: struct {
            booted: BootcStatus, // Tripwire so we have the expected structure.
            staged: ?BootcStatus = null,
        },
    };

    const bootc = try std.json.parseFromSliceLeaky(BootcOutput, mem, output, .{
        .ignore_unknown_fields = true,
    });
    return bootc.status.staged != null;
}

test "bootc json parse" {
    const testing = std.testing;

    const yes_staged = @embedFile("./testdata/bootc-with-staged.json");
    if (hasBootcAnythingStaged(testing.allocator, yes_staged)) |v| {
        try testing.expect(v == true);
    } else |err| {
        std.debug.print("Error yes: {}\n", .{err});
    }

    const no_staged = @embedFile("./testdata/bootc-nothing-staged.json");
    if (hasBootcAnythingStaged(testing.allocator, no_staged)) |v| {
        try testing.expect(v == false);
    } else |err| {
        std.debug.print("Error no: {}\n", .{err});
    }
}
