//! Functions for dealing with the monolithic XLS file that we need to 'modify'

const std = @import("std");
const libxls = root.libxls;
const xlsxio = root.xlsxio;
const root = @import("main.zig");
const revit = @import("revit.zig");

/// The offset from the first row of the spreadsheet the date is stored
pub const date_row_offset = 9;

/// The offset from the first coloum of the spreadsheet that the date is stored
/// (start of the first real date (not names)).
///
/// Do note that due to the formatting of the spreadsheet, the coloumn for the
/// date is actually shifted to the left, so any writes in reference to the
/// position of any of the dates should have 1 added to them.
pub const date_coloumn_offset = 4;

/// Clones and converts the XLS monolith to an un-styled XLSX spreadsheet;
/// updating revisions based upon the specified dates
pub fn convert(rows: []const revit.Row, dates: []const root.Date, reader: *libxls.xlsWorkSheet, writer: xlsxio.xlsxiowriter) void {
    // iterate through all of the rows of the worksheet
    for (0..reader.*.rows.lastrow+1) |r| {
        const row = libxls.xls_row(reader, @intCast(r));

        // check for if the row is updated in the revit spreadsheet
        // if so, then save the coloumn where the updated revision
        // should be written
        var rev_loc: ?u16 = null;
        var rev: [*:0]const u8 = undefined; // rev_loc is check for null
        for (rows) |rr| {
            // check for matches
            const cell = row.*.cells.cell[0].str orelse break;
            if (!std.mem.eql(u8, std.mem.span(rr.id), std.mem.span(cell))) continue;

            // if no fields then skip
            const revision = rr.revision orelse continue;
            const date = rr.date orelse continue;

            rev = revision;

            // get the date through searching then derive the rev location
            for (0.., dates) |i, d| {
                if (std.mem.eql(u16, &d, &date))
                    rev_loc = @intCast(i + date_coloumn_offset);
            }
        }

        // iterate through the coloumns and copy up until the revision update (if there is one)
        for (0..rev_loc orelse reader.*.rows.lastcol+1) |c| {
            const cell = row.*.cells.cell[c];
            xlsxio.xlsxiowrite_add_cell_string(writer, cell.str);
        }

        if (rev_loc) |loc| {
            // if there is a revision update, then update
            xlsxio.xlsxiowrite_add_cell_string(writer, rev);

            // copy the rest of the coloumns
            for (loc+1..reader.*.rows.lastcol+1) |c| {
                const cell = row.*.cells.cell[c];
                xlsxio.xlsxiowrite_add_cell_string(writer, cell.str);
            }
        }

        xlsxio.xlsxiowrite_next_row(writer);
    }
}

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
        array[c-date_coloumn_offset][0] = @intCast(cell.l + 2000);
    }

    return array;
}
