const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn main(init: std.process.Init) u8 {
    const allocator: Allocator = init.arena.allocator();
    const io = init.io;

    const output = std.process.run(allocator, io, .{
        .argv = &.{ "/usr/bin/bootc", "status", "--json" },
    }) catch {
        return 5; // ExitNotInstalled
    };
    // XXX: check output.term

    const need_reboot = hasBootcAnythingStaged(allocator, output.stdout) catch {
        std.Io.File.stderr().writeStreamingAll(io, output.stderr) catch {};
        return 6; // ExitNotConfigured
    };
    allocator.free(output.stdout);
    allocator.free(output.stderr);
    if (!need_reboot) {
        std.Io.File.stdout().writeStreamingAll(io, "Nothing staged") catch {};
        return 0; // ExitOK
    }

    std.process.replace(io, .{
        .argv = &.{ "/usr/bin/systemctl", "reboot" },
    }) catch {
        std.Io.File.stdout().writeStreamingAll(io, "Needs a reboot") catch {};
        return 1; // ExitFailure
    };
}

// Returns true based on the output of `bootc --json`.
fn hasBootcAnythingStaged(allocator: Allocator, output: []const u8) !bool {
    const bootcStatus = struct {
        pinned: bool,
        store: []u8,
    };
    const bootcOutput = struct {
        status: struct {
            booted: bootcStatus,
            staged: ?bootcStatus = null,
        },
    };

    const parsed = try std.json.parseFromSlice(
        bootcOutput,
        allocator,
        output,
        .{
            .ignore_unknown_fields = true,
        },
    );
    defer parsed.deinit();

    return parsed.value.status.staged != null;
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
