# comptimeDB
comptimeDB is a In-Memory database, (IMDb) intended to be used as a standalone process. 
The db process takes in requests from other processes to get/set from/to the database, setting up the getting/setting is up to the user
The request handiling is into the final db binary.
## Types
comptimeDB only works with i64, f64, and strings

## How to Use

### Import the db modules
```zig
const Entry = @import("entries.zig");
const db    = @import("comptimedb.zig");
```

### Define the entries of your db
```zig
    const entries = comptime [_]Entry.Entry{
        Entry.Entry.init("intName", 12, .{ .INT = 11 }, 4), // 11 is the default value of the 4 ints with id 12
        Entry.Entry.init("doubleName", 13, .{ .DOUBLE = 3.2 }, 4), // 3.2 is default value of the 4 doubles with id 13
        Entry.Entry.init("stringName", 14, .{ .STRING = 10 }, 13), // 10 is the default length of the 13 strings with id 14
    };
```

### Set the db to a variable
```zig
    const Table = db.GenTable(entries.len, entries);
    var table = comptime Table.init();
```



## How to Build
`zig build-exe <db_main_file_name>.zig`
