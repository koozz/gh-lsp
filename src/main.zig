const std = @import("std");
const lsp = @import("lsp.zig");

const ArrayList = std.ArrayList;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.log.err("Usage: gh lsp <file1> [file2] ...", .{});
        std.process.exit(1);
    }

    // Get LSP server command from environment variable
    const server_cmd = std.process.getEnvVarOwned(allocator, "GH_LSP_SERVER") catch |err| {
        switch (err) {
            error.EnvironmentVariableNotFound => {
                std.log.err("Environment variable GH_LSP_SERVER not found", .{});
                std.process.exit(1);
            },
            else => return err,
        }
    };
    defer allocator.free(server_cmd);

    // Parse server command into command and arguments
    var server_args = ArrayList([]const u8).init(allocator);
    defer server_args.deinit();

    var server_iter = std.mem.tokenizeAny(u8, server_cmd, " ");
    while (server_iter.next()) |arg| {
        try server_args.append(arg);
    }

    if (server_args.items.len == 0) {
        std.log.err("Invalid GH_LSP_SERVER command", .{});
        std.process.exit(1);
    }

    // Collect and validate if files exist
    var files = ArrayList([]const u8).init(allocator);
    defer files.deinit();
    for (args[1..]) |file_path| {
        std.fs.cwd().access(file_path, .{}) catch |err| {
            switch (err) {
                error.FileNotFound => {
                    std.log.err("File not found: {s}", .{file_path});
                    continue;
                },
                else => {
                    std.log.err("Cannot access file {s}: {}", .{ file_path, err });
                    continue;
                },
            }
        };
        try files.append(file_path);
    }
    if (files.items.len == 0) {
        std.log.err("No valid files provided", .{});
        std.process.exit(1);
    }

    try lsp.server(server_args.items, files, allocator);
}

// test "Verify version is up-to-date" {
//     // Future 0.15.0 version?
//     try std.testing.expectEqualStrings(@import("build.zig.zon").version, client_version);
// }

test "bash-language-server" {
    const allocator = std.testing.allocator;

    var files = ArrayList([]const u8).init(allocator);
    defer files.deinit();
    try files.append("test/bash-language-server.sh");

    try lsp.server(&[_][]const u8{ "bash-language-server", "start" }, files, allocator);
}

// test "biome" {
//     const allocator = std.testing.allocator;
//
//     var files = ArrayList([]const u8).init(allocator);
//     defer files.deinit();
//     try files.append("test/biome.ts");
//
//     try lsp.server(&[_][]const u8{ "biome", "lsp-proxy" }, files, allocator);
// }

// test "vale-ls" {
//     const allocator = std.testing.allocator;
//
//     var files = ArrayList([]const u8).init(allocator);
//     defer files.deinit();
//     try files.append("test/vale-ls.md");
//
//     try lsp.server(&[_][]const u8{ "vale-ls" }, files, allocator);
// }

test "superhtml" {
    const allocator = std.testing.allocator;

    var files = ArrayList([]const u8).init(allocator);
    defer files.deinit();
    try files.append("test/superhtml.html");

    try lsp.server(&[_][]const u8{ "superhtml", "lsp" }, files, allocator);
}

test "yaml-language-server" {
    const allocator = std.testing.allocator;

    var files = ArrayList([]const u8).init(allocator);
    defer files.deinit();
    try files.append("test/yaml-language-server.yaml");

    try lsp.server(&[_][]const u8{ "yaml-language-server", "--stdio" }, files, allocator);
}

// test "ziggy" {
//     const allocator = std.testing.allocator;
//
//     var files = ArrayList([]const u8).init(allocator);
//     defer files.deinit();
//     try files.append("test/ziggy.ziggy");
//
//     try lsp.server(&[_][]const u8{ "ziggy", "lsp" }, files, allocator);
// }

test "zls" {
    const allocator = std.testing.allocator;

    var files = ArrayList([]const u8).init(allocator);
    defer files.deinit();
    try files.append("test/zls.zig");

    try lsp.server(&[_][]const u8{"zls"}, files, allocator);
}
