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

    // Get LSP server timeout or use 3000 ms
    const lsp_timeout_ms = parse_timeout(allocator);

    try lsp.server(allocator, server_args.items, files, lsp_timeout_ms);
}

fn parse_timeout(allocator: std.mem.Allocator) usize {
    const default_timeout = 3000;
    const env_timeout = std.process.getEnvVarOwned(allocator, "GH_LSP_TIMEOUT_MS") catch null;
    if (env_timeout) |timeout_str| {
        defer allocator.free(timeout_str);
        return std.fmt.parseInt(usize, timeout_str, 10) catch default_timeout;
    } else {
        return default_timeout;
    }
}

// test "Verify version is up-to-date" {
//     // Future 0.15.0 version?
//     try std.testing.expectEqualStrings(@import("build.zig.zon").version, client_version);
// }

test "bash-language-server" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/bash-language-server.sh");

    lsp.server(std.testing.allocator, &[_][]const u8{ "bash-language-server", "start" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "biome" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/biome.ts");
    lsp.server(std.testing.allocator, &[_][]const u8{ "biome", "lsp-proxy" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "helm_ls" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/helm_ls.yaml");
    lsp.server(std.testing.allocator, &[_][]const u8{ "helm_ls", "serve" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "lua-language-server" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/lua-language-server.lua");
    lsp.server(std.testing.allocator, &[_][]const u8{"lua-language-server"}, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "marksman" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/marksman.md");
    lsp.server(std.testing.allocator, &[_][]const u8{"marksman"}, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "ruff" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/ruff.py");
    lsp.server(std.testing.allocator, &[_][]const u8{ "ruff", "server" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "superhtml" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/superhtml.html");
    lsp.server(std.testing.allocator, &[_][]const u8{ "superhtml", "lsp" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "typescript-language-server" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/typescript-language-server.ts");
    lsp.server(std.testing.allocator, &[_][]const u8{ "typescript-language-server", "--stdio" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "vale-ls" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/vale-ls.md");
    lsp.server(std.testing.allocator, &[_][]const u8{"vale-ls"}, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "yaml-language-server" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/yaml-language-server.yaml");
    lsp.server(std.testing.allocator, &[_][]const u8{ "yaml-language-server", "--stdio" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "ziggy" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/ziggy.ziggy");
    lsp.server(std.testing.allocator, &[_][]const u8{ "ziggy", "lsp" }, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}

test "zls" {
    var files = ArrayList([]const u8).init(std.testing.allocator);
    defer files.deinit();
    try files.append("test/zls.zig");
    lsp.server(std.testing.allocator, &[_][]const u8{"zls"}, files, 1000) catch |err| switch (err) {
        error.BrokenPipe => return error.SkipZigTest,
        else => {
            std.debug.print("Error: {}", .{err});
            try std.testing.expect(false);
        },
    };
}
