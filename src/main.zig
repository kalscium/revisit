pub const revit = @import("revit.zig");

// no lazy
comptime {
    _ = revit;
}

const std = @import("std");
const xlsxio = @cImport({
    @cInclude("xlsxio_read.h");
    @cInclude("xlsxio_write.h");
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
    // create an example sheet
    const writer = xlsxio.xlsxiowrite_open("text.xlsx", "nice")
        orelse return error.CannotCreateSheet;
    defer _ = xlsxio.xlsxiowrite_close(writer);

    // write to the first coloumn
    xlsxio.xlsxiowrite_set_row_height(writer, 1);
    xlsxio.xlsxiowrite_add_column(writer, "example", 0);
    xlsxio.xlsxiowrite_next_row(writer);
    xlsxio.xlsxiowrite_add_cell_string(writer, "hello, world!");

    // read from example xls file
    var xls_error: c_uint = @intCast(libxls.LIBXLS_OK);
    const wb = libxls.xls_open_file("example.xls", "UTF-8", &xls_error);
    defer libxls.xls_close(wb);
    if (wb == null)
        return error.UnableToOpenXLS;
}
