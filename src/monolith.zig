//! Functions for dealing with the monolithic XLS file that we need to 'modify'

const std = @import("std");
const libxls = @cImport({
    @cInclude("xls.h");
});
const root = @import("main.zig");

/// The offset from the first row of the spreadsheet the date is stored
pub const date_row_offset = 9;

/// The offset from the first coloum of the spreadsheet that the date is stored
/// (start of the first real date (not names))
pub const date_coloumn_offset = 4;

/// Parses and returns the dates (owned by the caller) specified within the 
/// monolith spreadsheet
pub fn parseDates(allocator: std.mem.Allocator, sheet: *libxls.xlsWorkSheet) ![]const root.Date {
    // allocate the required memory
    const array: []root.Date = try allocator.alloc(root.Date, sheet.*.rows.lastcol-date_coloumn_offset+1);

    // get the day of the dates
    const day_row = libxls.xls_row(sheet, date_row_offset);
    for (date_coloumn_offset..sheet.*.rows.lastcol+1) |c| {
        const cell = day_row.*.cells.cell[c];
        array[c-date_coloumn_offset][2] = @intCast(cell.l);
    }

    // get the month of the dates
    const month_row = libxls.xls_row(sheet, date_row_offset+1);
    for (date_coloumn_offset..sheet.*.rows.lastcol+1) |c| {
        const cell = month_row.*.cells.cell[c];
        array[c-date_coloumn_offset][1] = @intCast(cell.l);
    }

    // get the year of the dates
    const year_row = libxls.xls_row(sheet, date_row_offset+2);
    for (date_coloumn_offset..sheet.*.rows.lastcol+1) |c| {
        const cell = year_row.*.cells.cell[c];
        array[c-date_coloumn_offset][0] = @intCast(cell.l);
    }

    return array;
}
