const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const kayscript = @import("kayscript");

pub fn main(init: std.process.Init) !void {
    const res = try lsblk(init.gpa, init.io);
    defer init.gpa.destroy(res);

    const entries = res.blockdevices;

    for(entries) |ent| {
        std.debug.print("{s}\n", .{ent.name});
    }
}

const LsblkEntry = struct {
    name: []const u8,
    type: []const u8,
    @"id-link": ?[]const u8,
    size: []const u8,
};

const LsblkOutput = struct {
    blockdevices: []LsblkEntry,
};

fn lsblk(gpa: Allocator, io: Io) !*LsblkOutput {
    const cmd = try std.process.run(gpa, io, .{
        .argv = &.{ "lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK" },
    });
    defer gpa.free(cmd.stderr);
    defer gpa.free(cmd.stdout);

    getCmdError(cmd) catch |err| {
        std.debug.print("{s}\n", .{cmd.stderr});
        return err;
    };

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        gpa, 
        cmd.stdout, 
        .{.ignore_unknown_fields = true},
    );
    defer parsed.deinit();

    const res_ptr = try gpa.create(LsblkOutput);
    res_ptr.* = parsed.value;
    return res_ptr;
}

fn getCmdError(cmd: std.process.RunResult) error{CommandFailed, CommandTerminated}!void {
    switch(cmd.term) {
        .exited => |code| if(code != 0) return error.CommandFailed,
        else => return error.CommandTerminated,
    }
}