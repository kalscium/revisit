//! Code for reading the Revit-generated excel spreadsheets

const std = @import("std");

/// A single row in the revit spreadsheet
pub const Row = struct {
    id: [:0]const u8,
    name: [:0]const u8,
    revision: [:0]const u8,
    date: Date,
};

/// A numeric date in the format of `yyyy/mm/dd`
pub const Date = [3]u16;

/// Deserializes / parses the date in the string format `dd/mm/yyyy`
pub fn parseDate(date: [:0]const u8) !Date {
    var date_array: Date = undefined;

    // parse the strings
    var iter = std.mem.splitScalar(u8, date, '/');
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
    const date = "02/03/2025";
    const date_array = try parseDate(date);
    std.debug.assert(std.mem.eql(u16, &date_array, &.{ 2025, 3, 2 }));
}
