//! Code for reading the Revit-generated excel spreadsheets

const std = @import("std");
const xlsxio = @cImport({
    @cInclude("xlsxio_read.h");
});

/// A single row in the revit spreadsheet
pub const Row = struct {
    id: [*:0]u8,
    name: [*:0]u8,
    revision: ?[*:0]u8,
    date: ?Date,

    /// Parses a row in a revit-generated spreadsheet
    pub fn parse(reader: xlsxio.xlsxioreadersheet) ?Row {
        const id = xlsxio.xlsxioread_sheet_next_cell(reader);
        const name = xlsxio.xlsxioread_sheet_next_cell(reader);

        // check if there's even any contents
        if (cellEmpty(@ptrCast(id)))
            return null;

        // get the revision if there is one
        var revision = xlsxio.xlsxioread_sheet_next_cell(reader);
        if (cellEmpty(@ptrCast(revision.?)))
            revision = null;

        // get the date if there is one
        const date_raw = xlsxio.xlsxioread_sheet_next_cell(reader);
        _ = xlsxio.xlsxioread_free(xlsxio.xlsxioread_sheet_next_cell(reader)); // makes it work for some reason, don't touch it
        defer xlsxio.xlsxioread_free(date_raw);
        var date: ?Date = undefined;
        if (cellEmpty(date_raw))
            date = null
        else
            date = parseDate(@ptrCast(date_raw)) catch null;

        // _ = xlsxio.xlsxioread_sheet_next_row(reader);

        // return the parsed row
        return .{
            .id = @ptrCast(id),
            .name = @ptrCast(name),
            .revision = @ptrCast(revision),
            .date = date,
        };
    }

    /// Frees the memory stored in the row
    pub fn deinit(self: Row) void {
        xlsxio.xlsxioread_free(@ptrCast(self.id));
        xlsxio.xlsxioread_free(@ptrCast(self.name));
        if (self.revision) |rev| xlsxio.xlsxioread_free(rev);
    }
};

/// A numeric date in the format of `yyyy/mm/dd`
pub const Date = [3]u16;

/// Checks if the contents of a cell is empty or not
pub fn cellEmpty(contents: ?[*:0]const u8) bool {
    const contents_span = std.mem.span(contents orelse return true);

    return std.mem.eql(u8, contents_span, "") or std.mem.eql(u8, contents_span, "'-") or std.mem.eql(u8, contents_span, "-");
}

/// Deserializes / parses the date in the string format `dd/mm/yyyy`
pub fn parseDate(date: [*:0]const u8) !Date {
    var date_array: Date = undefined;

    // parse the strings
    const data_slice = std.mem.span(date);
    var iter = std.mem.splitScalar(u8, data_slice, '.');
    var idx: usize = 0;
    while (iter.next()) |seg| : (idx += 1) {
        // parse the segment
        date_array[2-idx] = try std.fmt.parseInt(u16, seg, 10);

        // if finished
        if (idx == 2) break;
    }

    // return the converted date
    return date_array;
}

test parseDate {
    const date = "02.03.2025";
    const date_array = try parseDate(date);
    std.debug.assert(std.mem.eql(u16, &date_array, &.{ 2025, 3, 2 }));
}
