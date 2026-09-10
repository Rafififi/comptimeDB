
pub const Entry = struct {
    name: []const u8,
    id: usize,
    entry_type: EntryType,
    num_elems: usize,

    const Self = @This();
    pub fn init(comptime name: []const u8, comptime id: usize, comptime entry_type: EntryType, comptime num_elems: usize) Self {
        return Self { .name = name, .id = id, .entry_type = entry_type, .num_elems = num_elems };
    } 
    pub const EntryType = union(enum) {
        INT: i64,
        DOUBLE: f64,
        STRING: usize,
    };
};


pub const GetMessage = packed struct {
    id: usize,
    idx: usize,
    msg_type: Type,
    pub const Type = enum(u8) {
        INT,
        FLOAT,
        DOUBLE,
    };
};

fn GenSetMessage(comptime T: type) type {
    return packed struct {
        id:  usize,
        idx: usize,
        msg: T,
    };
}

pub const SetInt = GenSetMessage(i64);
pub const SetDouble = GenSetMessage(f64);
pub const SetString = GenSetMessage([1024]u8);

pub const Set = enum {
    FAIL,
    SUCCESS,
};
