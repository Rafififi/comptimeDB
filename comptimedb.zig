const std = @import("std");
const Entry = @import("entries.zig");

const InvalidIdError = error {
    InvalidId,
};

const OffsetRes = struct {
    offset: usize,
    len: usize,
};


const offset_func = *const fn (usize) InvalidIdError!OffsetRes;

pub fn GenTable(num_entries: usize, comptime entries: [num_entries]Entry.Entry) type {
    const size_info = get_entries_info(num_entries, entries);
    const num_int = size_info.num_int;
    const num_dub = size_info.num_dub;
    const num_str = size_info.num_str;
    const size_int = size_info.size_int;
    const size_dub = size_info.size_dub;
    const size_str = size_info.size_str;
    verify_entires(num_entries, entries);

    return struct {
        int_table: [size_int]u8,
        double_table: [size_dub]u8,
        string_table: [size_str]u8,
        int_offset_func: offset_func,
        dub_offset_func: offset_func,
        str_offset_func: offset_func,

        const Self = @This();

        pub fn get_int(self: *Self, id: usize, idx: usize) ?i64 {
            const offset_res = self.int_offset_func(id) catch return null;
            if (idx > offset_res.len) return null;
            const int_i64: *const [size_int/8]i64 = @ptrCast(@alignCast(&self.int_table));
            return int_i64[(offset_res.offset/8) + idx];
        }
        pub fn set_int(self: *Self, id: usize, idx: usize, val: i64) ?i64 {
            const offset_res = self.int_offset_func(id) catch return null;
            if (idx > offset_res.len) return null;
            const int_i64: *[size_int/8]i64 = @constCast(@ptrCast(@alignCast(&self.int_table)));
            int_i64[(offset_res.offset/8) + idx] = val;
            return int_i64[(offset_res.offset/8) + idx];
        }
        pub fn get_double(self: *Self, id: usize, idx: usize) ?f64 {
            const offset_res = self.dub_offset_func(id) catch return null;
            if (idx > offset_res.len) return null;
            const dub_f64: *const [size_dub/8]f64 = @ptrCast(@alignCast(&self.double_table));
            return dub_f64[(offset_res.offset/8) + idx];
        }
        pub fn set_double(self: *Self, id: usize, idx: usize, val: f64) ?f64 {
            const offset_res = self.dub_offset_func(id) catch return null;
            if (idx > offset_res.len) return null;
            const dub_f64: *[size_dub/8]f64 = @constCast(@ptrCast(@alignCast(&self.double_table)));
            dub_f64[(offset_res.offset/8) + idx] = val;
            return dub_f64[(offset_res.offset/8) + idx];
        }
        pub fn get_string(self: *Self, id: usize, idx: usize) ?[]u8 {
            const offset_res = self.str_offset_func(id) catch return null;
            const offset = offset_res.offset;
            const len    = offset_res.len;
            const starting_idx = (offset/8) + (idx * len);
            const ending_idx = (offset/8) + ((idx + 1) * len);
            return self.string_table[starting_idx..ending_idx];
        }
        pub fn set_string(self: *Self, id: usize, idx: usize, val: []const u8) ?void {
            const offset_res = self.str_offset_func(id) catch return null;
            const offset = offset_res.offset;
            const len    = offset_res.len;
            if (val.len > len) return null;
            const starting_idx = (offset/8) + (idx * len);
            var dst_idx = starting_idx;
            for (val) |src| {
                self.string_table[dst_idx] = src;
                dst_idx += 1;
            }
            return;
        }

        pub fn init() Self {
            var self: Self = undefined;
            comptime {
                const pairs = gen_offset_pairs(num_entries, entries, num_int, num_dub, num_str);
                self.int_offset_func = gen_offset_table(pairs.int_pairs);
                self.dub_offset_func = gen_offset_table(pairs.dub_pairs);
                self.str_offset_func = gen_offset_table(pairs.str_pairs);

                var int_offset = 0;
                var dub_offset = 0;
                for (entries) |entry| {
                    switch (entry.entry_type) {
                        .INT => |val| {
                            var int_i64: *[size_int/8]i64 = @ptrCast(@alignCast(&self.int_table));
                            for (int_offset/8..int_offset/8 + entry.num_elems) |i| {
                                int_i64[i] = val;
                            }
                            int_offset += entry.num_elems * 8;
                        },
                        .DOUBLE=> |val| {
                            var dub_f64: *[size_dub/8]f64 = @ptrCast(@alignCast(&self.double_table));
                            for (dub_offset/8..((dub_offset/8) + entry.num_elems)) |i| {
                                dub_f64[i] = val;
                            }
                            dub_offset += entry.num_elems * 8;
                        },
                        .STRING => {},
                    }
                }
            }
            return self;
        }
        pub fn dump(self: *const Self) void {
            const int_i64: *const [size_int/8]i64 = @ptrCast(@alignCast(&self.int_table));
            for (int_i64.*) |int| {
                std.debug.print("{}, ", .{int});
            }
            std.debug.print("\n", .{});
            const dub_f64: *const [size_dub/8]f64 = @ptrCast(@alignCast(&self.double_table));
            for (dub_f64.*) |int| {
                std.debug.print("{}, ", .{int});
            }
            std.debug.print("\n", .{});
            for (self.string_table) |int| {
                std.debug.print("{c}, ", .{int});
            }
            std.debug.print("\n", .{});
        }
        pub fn get_int_io(self: *Self, in: *std.Io.Reader, out: *std.Io.Writer) ?i64 {
            std.debug.print("1\n", .{});
            const message: Entry.GetMessage = in.takeStruct(Entry.GetMessage, .big) catch return null;
            std.debug.print("2\n", .{});
            const res: i64 = switch (message.msg_type) {
                .INT => self.get_int(message.id, message.idx) orelse return null,
                else => return null,
            };
            out.writeAll(std.mem.asBytes(&res)) catch return null;
            out.flush() catch return null;
            return res;
        }
        pub fn get_double_io(self: *Self, in: *std.Io.Reader, out: *std.Io.Writer) ?f64 {
            const message: Entry.GetMessage = in.takeStruct(Entry.GetMessage, .big) catch return null;
            const res: f64 = switch (message.msg_type) {
                .DOUBLE => self.get_double(message.id, message.idx) orelse return null,
                else => null,
            };
            out.writeAll(std.mem.asBytes(&res)) catch return null;
            out.flush() catch return null;
            return res;
        }
        pub fn get_str_io(self: *Self, in: *std.Io.Reader, out: *std.Io.Writer) ?[]u8 {
            const message: Entry.GetMessage = in.takeStruct(Entry.GetMessage, .big) catch return null;
            const res: []u8 = switch (message.msg_type) {
                .STRING => self.get_string(message.id, message.idx) orelse return null,
                else => null,
            };
            out.writeAll(std.mem.asBytes(&res)) catch return null;
            out.flush() catch return null;
            return res;
        }
        pub fn set_str_io(self: *Self, in: *std.Io.Reader) Entry.Set {
            const message: Entry.SetString = in.takeStruct(Entry.SetString, .big) catch return .FAIL;
            self.set_string(message.id, message.idx, &message.msg) orelse return .FAIL;
            return .SUCCESS;
        }
        pub fn set_int_io(self: *Self, in: *std.Io.Reader) Entry.Set {
            const message: Entry.SetInt = in.takeStruct(Entry.SetInt, .big) catch return .FAIL;
            self.set_int(message.id, message.idx, message.msg) orelse return .FAIL;
            return .SUCCESS;
        }
        pub fn set_double_io(self: *Self, in: *std.Io.Reader) Entry.Set {
            const message: Entry.SetDouble = in.takeStruct(Entry.SetDouble, .big) catch return .FAIL;
            self.set_double(message.id, message.idx, message.msg) orelse return .FAIL;
            return .SUCCESS;
        }
    };
}

fn verify_entires(num_entries: comptime_int, comptime entries: [num_entries]Entry.Entry) void {
    comptime {
        const NamePair = struct {id: usize, name: []const u8};
        var ids: [entries.len]NamePair = undefined;
        for (entries, 0..) |entry, i| {
            for (0..i) |j|{
                if (ids[j].id == entry.id) {
                    @compileError(std.fmt.comptimePrint("2 Entries have the same ID {d}! {s} and {s}", .{ids[i].id, ids[i].name, entry.name}));
                }
            }
            if (entry.id == 0) {
                @compileError(std.fmt.comptimePrint("Entry {} has ID 0", .{entry.name}));
            }
            ids[i].id = entry.id;
            ids[i].name = entry.name;
        }
    }
}

const SizeInfo = struct {
    num_int: comptime_int,
    num_dub: comptime_int,
    num_str: comptime_int,
    size_int: comptime_int,
    size_dub: comptime_int,
    size_str: comptime_int,
};

fn get_entries_info(num_entries: usize, comptime entries: [num_entries]Entry.Entry) SizeInfo{
    var size_int = 0;
    var size_dub = 0;
    var size_str = 0;
    var num_int = 0;
    var num_dub = 0;
    var num_str = 0;
    for (entries) |entry| {
        switch (entry.entry_type) {
            .INT    => {
                num_int  += 1;
                size_int += entry.num_elems * @sizeOf(i64);
            },
            .DOUBLE => {
                num_dub  += 1;
                size_dub += entry.num_elems * @sizeOf(f64);
            },
            .STRING => |val| {
                num_str  += 1;
                size_str += entry.num_elems * val;
            },
        }
    }
    return .{
            .num_int = num_int,
            .num_dub = num_dub,
            .num_str = num_str,
            .size_int = size_int,
            .size_dub = size_dub,
            .size_str = size_str
        };
}


const OffsetInfo = struct {k: usize, v: usize, len: usize};
const Pairs = struct {
    int_pairs: []OffsetInfo,
    dub_pairs: []OffsetInfo,
    str_pairs: []OffsetInfo,
};
fn gen_offset_pairs(num_entries: comptime_int, comptime entries: [num_entries]Entry.Entry, num_int: comptime_int, num_dub: comptime_int, num_str: comptime_int ) Pairs {
    comptime var int_pairs: [num_int]OffsetInfo = undefined;
    comptime var dub_pairs: [num_dub]OffsetInfo = undefined;
    comptime var str_pairs: [num_str]OffsetInfo = undefined;
    var int_offset = 0;
    var dub_offset = 0;
    var str_offset = 0;

    var int_idx = 0;
    var dub_idx = 0;
    var str_idx = 0;
    for (entries) |entry| {
        switch (entry.entry_type) {
            .INT => {
                int_pairs[int_idx].k = entry.id;
                int_pairs[int_idx].v = int_offset;
                int_pairs[int_idx].len = entry.num_elems;
                int_idx += 1;
                int_offset += entry.num_elems * 8;

            },
            .DOUBLE => {
                dub_pairs[dub_idx].k = entry.id;
                dub_pairs[dub_idx].v = dub_offset;
                dub_pairs[dub_idx].len = entry.num_elems;
                dub_idx += 1;
                dub_offset += entry.num_elems * 8;
            },
            .STRING => |val| {
                str_pairs[str_idx].k = entry.id;
                str_pairs[str_idx].v = str_offset;
                str_pairs[str_idx].len = val;
                str_idx += 1;
                str_offset += entry.num_elems * val;
            },
        }
    }
    return Pairs{.int_pairs = &int_pairs, .dub_pairs = &dub_pairs, .str_pairs = &str_pairs};
}

fn gen_offset_table(comptime pairs: []OffsetInfo) offset_func {
    comptime var temp: [pairs.len]OffsetInfo = undefined;
    for (pairs, 0..) |pair, i| {
        temp[i] = pair;
    }
    comptime {
        return struct {
            fn f(id: usize) InvalidIdError!OffsetRes {
                inline for (temp) |pair| {
                    if (pair.k == id) return .{ .offset = pair.v, .len = pair.len};
                }
                else {
                    return InvalidIdError.InvalidId;
                }
            }
        }.f;
    }
}
