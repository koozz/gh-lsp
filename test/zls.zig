// This is a Zig program with various issues to test diagnostics
// and ensure that the language server catches them correctly.
const std = @import("std");

pub fn main() !void {
    // This function has several issues for testing

    // Unused import (std.ArrayList not used)
    const ArrayList = std.ArrayList;

    // Variable declared but never used
    var unused_var: i32 = 10;

    // Wrong function call - incorrect number of arguments
    const result = multiply(5); // multiply expects 2 arguments
    std.debug.print("Result: {}\n", .{result});

    // Type mismatch
    var number: u32 = -5; // Negative value assigned to unsigned type

    // Dead code after return
    return;
    std.debug.print("This is unreachable\n", .{});
}

// Function with missing parameter
fn multiply(a: i32) i32 {
    return a * b; // 'b' is undefined
}

// Function that returns wrong type
fn getString() i32 {
    return "hello"; // String returned instead of i32
}

// Infinite recursion
fn infiniteLoop() void {
    infiniteLoop();
}
