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
pub const xlsxio = @cImport({
    @cInclude("xlsxio_read.h");
    @cInclude("xlsxio_write.h");
});
pub const libxls = @cImport({
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

const revit_xlsx_path = "revit.xlsx";
const monolith_xls_path = "monolith.xls";
const output_xlsx_path = "output.xlsx";

fn run() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arena.allocator();

    // read from the example revit file 
    const reader = xlsxio.xlsxioread_open(revit_xlsx_path);
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
    while (row_exists) : (row_exists = try revit.Row.parse(sheet, &rows))
        if (xlsxio.xlsxioread_sheet_next_row(sheet) != 1)
            break;

    // read from example xls file
    var xls_error: c_uint = @intCast(libxls.LIBXLS_OK);
    const wb = libxls.xls_open_file(monolith_xls_path, "UTF-8", &xls_error);
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

    // open the writer to the output spreadsheet
    const writer = xlsxio.xlsxiowrite_open(output_xlsx_path, "output");
    if (writer == null)
        return error.UnableToCreateXLSX;
    defer _ = xlsxio.xlsxiowrite_close(writer);

    // convert the monolith
    monolith.convert(rows.items, dates, ws, writer);
}
