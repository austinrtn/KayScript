const std = @import("std");
const Allocator = std.mem.Allocator;
const Io = std.Io;

const kayscript = @import("kayscript");

pub fn main(init: std.process.Init) !void {
    const allocator = init.arena.allocator();
    const io = init.io;
    
    var stdin_buf: [1024]u8 = undefined;
    var reader = std.Io.File.stdin().reader(io, &stdin_buf);
    const stdin = &reader.interface;
    
    var stdout_buf: [1024]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &stdout_buf);
    const stdout = &writer.interface;
    cls(stdout);
    
    const res = try lsblk(allocator, io);
    const entries = res.blockdevices;

    try stdout.writeAll("Select a Block Device: \n");
    for(entries, 0..) |ent, i| {
        try stdout.print("{d}: {s}\n", .{i, ent.name});
    }
    try stdout.flush();

    const resp = try stdin.takeDelimiterExclusive('\n');
    const idx = try std.fmt.parseInt(usize, resp, 0);
    try stdout.print("You etnered: {s}", .{entries[idx].name});
    try stdout.flush();
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

fn cls(stdout: *std.Io.Writer) void {
    stdout.writeAll("\x1b[2J\x1b[H") catch @panic("Unable to clear screen");
    stdout.flush() catch @panic("Unable to clear screen");
}

fn lsblk(allocator: Allocator, io: Io) !*LsblkOutput {
    const cmd = try std.process.run(allocator, io, .{
        .argv = &.{ "lsblk", "--json", "--output", "NAME,TYPE,SIZE,ID-LINK" },
    });

    getCmdError(cmd) catch |err| {
        std.debug.print("{s}\n", .{cmd.stderr});
        return err;
    };

    const parsed = try std.json.parseFromSlice(
        LsblkOutput,
        allocator, 
        cmd.stdout, 
        .{.ignore_unknown_fields = true},
    );

    const res_ptr = try allocator.create(LsblkOutput);
    res_ptr.* = parsed.value;
    return res_ptr;
}

fn getCmdError(cmd: std.process.RunResult) error{CommandFailed, CommandTerminated}!void {
    switch(cmd.term) {
        .exited => |code| if(code != 0) return error.CommandFailed,
        else => return error.CommandTerminated,
    }
}