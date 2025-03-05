pub const revit = @import("revit.zig");
pub const monolith = @import("monolith.zig");

/// A numeric date in the format of `yyyy/mm/dd`
pub const Date = [3]u16;

// no lazy
comptime {
    _ = revit;
    _ = monolith;
}

const std = @import("std");
const xlsxio = @cImport({
    @cInclude("xlsxio_read.h");
});
const libxls = @cImport({
    @cInclude("xls.h");
});

const error_file_path = "ERROR.txt";

pub fn main() !void {
    // remove any previous errors if there are any
    std.fs.cwd().deleteFile(error_file_path) catch {};

    // Error handling
    if (run()) {}
    else |err| {
        // write to error file
        var file = try std.fs.cwd().createFile(error_file_path, .{});
        try std.fmt.format(file.writer(), "{}", .{err});
        file.close();
        return err;
    }
}

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    // read from the example revit file 
    const reader = xlsxio.xlsxioread_open("revit.xlsx");
    if (reader == null)
        return error.UnableToOpenXLSX;
    const sheet_name: ?[*:0]u8 = null;
    const sheet = xlsxio.xlsxioread_sheet_open(reader, sheet_name, xlsxio.XLSXIOREAD_SKIP_NONE);
    if (sheet == null)
        return error.NoXLSXSheets;
    if (xlsxio.xlsxioread_sheet_next_row(sheet) != 1)
        return error.EmptyXLSX;

    // iterate through and create an arraylist of all the parsed rows
    var rows = std.ArrayList(revit.Row).init(allocator);
    defer {
        // free rows
        for (rows.items) |row|
            row.deinit();
        rows.deinit();
    }

    var row_exists = try revit.Row.parse(sheet, &rows);
    while (row_exists) : (row_exists = try revit.Row.parse(sheet, &rows)) {
        // get row
        const row = &rows.getLast();

        std.debug.print("row: {{ .id = \"{s}\", .name = \"{s}\", .revision = \"{s}\", .date = {any} }}\n", .{
            row.id,
            row.name,
            row.revision orelse "null",
            row.date orelse Date{ 0, 0, 0 },
        });
        if (xlsxio.xlsxioread_sheet_next_row(sheet) != 1)
            break;
    }

    // read from example xls file
    var xls_error: c_uint = @intCast(libxls.LIBXLS_OK);
    const wb = libxls.xls_open_file("monolith.xls", "UTF-8", &xls_error);
    defer libxls.xls_close(wb);
    if (wb == null)
        return error.UnableToOpenXLS;
    const ws = libxls.xls_getWorkSheet(wb, 0);
    if (libxls.xls_parseWorkSheet(ws) != 0)
        return error.InvalidXLSSheet;
    defer libxls.xls_close_WS(ws);

    // get xls date
    const dates = try monolith.parseDates(allocator, ws);
    defer allocator.free(dates);
    std.debug.print("dates: {any}\n", .{dates});
}
