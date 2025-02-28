const std = @import("std");
const string = []const u8;
const builtin = @import("builtin");
pub const build_options = @import("build_options");
const zigmod = @import("zigmod");
const win32 = @import("win32");

pub const u = @import("./util/index.zig");
pub const common = @import("./common.zig");

//
//

pub fn main() !void {
    const gpa = std.heap.c_allocator;

    const proc_args = try std.process.argsAlloc(gpa);
    const args = proc_args[1..];

    const available = if (build_options.bootstrap) zigmod.commands_to_bootstrap else zigmod.commands;

    if (args.len == 0) {
        std.debug.print("zigmod {s} {s} {s} {s}\n", .{
            build_options.version,
            @tagName(builtin.os.tag),
            @tagName(builtin.cpu.arch),
            @tagName(builtin.abi),
        });
        std.debug.print("\n", .{});
        std.debug.print("The commands available are:\n", .{});
        inline for (comptime std.meta.declarations(available)) |decl| {
            std.debug.print("  - {s}\n", .{decl.name});
        }
        return;
    }

    if (!build_options.bootstrap and builtin.os.tag == .windows) {
        const console = win32.system.console;
        const h_out = console.GetStdHandle(console.STD_OUTPUT_HANDLE);
        _ = console.SetConsoleMode(h_out, console.CONSOLE_MODE.initFlags(.{
            .ENABLE_PROCESSED_INPUT = 1, //ENABLE_PROCESSED_OUTPUT
            .ENABLE_LINE_INPUT = 1, //ENABLE_WRAP_AT_EOL_OUTPUT
            .ENABLE_ECHO_INPUT = 1, //ENABLE_VIRTUAL_TERMINAL_PROCESSING
        }));
    }

    try zigmod.init();
    defer zigmod.deinit();

    inline for (comptime std.meta.declarations(available)) |decl| {
        if (std.mem.eql(u8, args[0], decl.name)) {
            const cmd = @field(available, decl.name);
            try cmd.execute(args[1..]);
            return;
        }
    }

    var sub_cmd_args = std.ArrayList(string).init(gpa);
    try sub_cmd_args.append(try std.fmt.allocPrint(gpa, "zigmod-{s}", .{args[0]}));
    for (args[1..]) |item| {
        try sub_cmd_args.append(item);
    }
    const result = std.ChildProcess.exec(.{ .allocator = gpa, .argv = sub_cmd_args.items }) catch |e| switch (e) {
        else => return e,
        error.FileNotFound => {
            u.fail("unknown command \"{s}\" for \"zigmod\"", .{args[0]});
        },
    };
    try std.io.getStdOut().writeAll(result.stdout);
    try std.io.getStdErr().writeAll(result.stderr);
}
