const std = @import("std");
const xlsxio = @cImport({
    @cInclude("xlsxio_read.h");
    @cInclude("xlsxio_write.h");
});

pub fn main() !void {
    // create an example sheet
    const writer = xlsxio.xlsxiowrite_open("text.xlsx", "nice")
        orelse return error.CannotCreateSheet;
    defer _ = xlsxio.xlsxiowrite_close(writer);

    // write to the first coloumn
    xlsxio.xlsxiowrite_set_row_height(writer, 1);
    xlsxio.xlsxiowrite_add_column(writer, "example", 0);
    xlsxio.xlsxiowrite_next_row(writer);
    xlsxio.xlsxiowrite_add_cell_string(writer, "hello, world!");
}
