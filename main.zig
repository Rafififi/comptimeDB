const std   = @import("std");
const Entry = @import("entries.zig");
const db    = @import("comptimedb.zig");


pub fn main(init: std.process.Init) void {
    _ = init;
    const entries = comptime [_]Entry.Entry{
        Entry.Entry.init("intName", 12, .{ .INT = 11 }, 4),
        Entry.Entry.init("doubleName", 13, .{ .DOUBLE = 3.2 }, 4),
        Entry.Entry.init("stringName", 14, .{ .STRING = 10 }, 13),
        Entry.Entry.init("intName", 15, .{ .INT = 21 }, 4),
        Entry.Entry.init("doubleName", 16, .{ .DOUBLE = 2.2 }, 3),
    };
    const Table = db.GenTable(entries.len, entries);
    var table = comptime Table.init();
    std.debug.print("Table info:\n", .{});
    std.debug.print("Int size: {}\n", .{@sizeOf(@TypeOf(table.int_table))});
    std.debug.print("Double size: {}\n", .{@sizeOf(@TypeOf(table.double_table))});
    std.debug.print("string size: {}\n", .{@sizeOf(@TypeOf(table.string_table))});
    table.dump();
    _ = table.set_double(13, 3, 12.3) orelse unreachable;
    table.dump();
}
