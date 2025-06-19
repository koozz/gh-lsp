const std = @import("std");
const json = std.json;
const ArrayList = std.ArrayList;
const Allocator = std.mem.Allocator;

// Replace with @import("build.zig.zon").version when available
const client_version = "0.1.1";

var message_id: i64 = 1;

const MessageContext = struct {
    stdin: std.fs.File,
    stdout: std.fs.File,
    allocator: Allocator,
    files: ArrayList([]const u8),
    server_capabilities: ?json.Value = null,
    initialized: bool = false,
    diagnostics_supported: bool = false,
    files_opened: u32 = 0,
    diagnostics_received: u32 = 0,
    should_exit: bool = false,
};

pub fn server(server_args: []const []const u8, files: ArrayList([]const u8), allocator: Allocator) !void {
    std.log.info("Spawning language server: {s}", .{server_args[0]});

    // Start the language server process
    var process = std.process.Child.init(server_args, allocator);
    process.stdin_behavior = .Pipe;
    process.stdout_behavior = .Pipe;
    process.stderr_behavior = .Pipe;

    try process.spawn();

    if (process.stdin == null or process.stdout == null) {
        std.log.err("Failed to create pipes to language server", .{});
        return error.ProcessPipeFailed;
    }

    // Create message processing context
    var context = MessageContext{
        .stdin = process.stdin.?,
        .stdout = process.stdout.?,
        .allocator = allocator,
        .files = files,
    };

    // Start message processing thread
    const thread = try std.Thread.spawn(.{}, processMessages, .{&context});

    // Send initialize request
    try sendInitialize(&context);

    // Wait for processing to complete
    thread.join();

    // Shutdown the server gracefully
    try sendShutdown(&context);
    try sendExit(&context);

    // Wait for server to exit
    _ = try process.wait();

    std.log.debug("Language server session completed", .{});
}

fn processMessages(context: *MessageContext) void {
    var buffer: [16384]u8 = undefined;

    while (!context.should_exit) {
        const parsed_message = readMessage(context.stdout, &buffer, context.allocator) catch |err| {
            switch (err) {
                error.EndOfStream => {
                    std.log.info("Language server disconnected", .{});
                    break;
                },
                else => {
                    std.log.err("Error reading message: {}", .{err});
                    break;
                },
            }
        };
        defer parsed_message.deinit();

        handleMessage(context, parsed_message.value) catch |err| {
            std.log.err("Error handling message: {}", .{err});
        };

        // Check if we should exit (all diagnostics received)
        if (context.initialized and
            context.files_opened == context.files.items.len and
            context.diagnostics_received >= context.files.items.len)
        {
            context.should_exit = true;
        }
    }
}

fn readMessage(stdout: std.fs.File, buffer: []u8, allocator: Allocator) !json.Parsed(json.Value) {
    const reader = stdout.reader();

    // Read headers
    var content_length: ?usize = null;
    while (true) {
        const line = reader.readUntilDelimiterOrEof(buffer, '\n') catch |err| {
            return err;
        } orelse return error.EndOfStream;

        if (line.len <= 1) { // Empty line or just \r
            break;
        }

        if (std.mem.startsWith(u8, line, "Content-Length:")) {
            const value_start = std.mem.indexOf(u8, line, ":").? + 1;
            const value = std.mem.trim(u8, line[value_start..], " \r\n\t");
            content_length = try std.fmt.parseInt(usize, value, 10);
        }
    }

    if (content_length == null) {
        return error.MissingContentLength;
    }

    // Read message body
    const message_buffer = try allocator.alloc(u8, content_length.?);
    defer allocator.free(message_buffer);

    const bytes_read = try reader.readAll(message_buffer);
    if (bytes_read != content_length.?) {
        return error.IncompleteRead;
    }

    // Parse JSON
    return try json.parseFromSlice(json.Value, allocator, message_buffer, .{});
}

fn handleMessage(context: *MessageContext, message: json.Value) !void {
    const msg_obj = message.object;
    if (msg_obj.get("result")) |result| {
        if (!context.initialized) {
            context.server_capabilities = result;
            context.initialized = true;

            if (result.object.get("capabilities")) |capabilities| {
                if (capabilities.object.get("textDocumentSync") != null or
                    capabilities.object.get("diagnosticProvider") != null)
                {
                    context.diagnostics_supported = true;
                }
            }

            std.log.info("Server initialized, diagnostics supported: {}", .{context.diagnostics_supported});

            try sendNotification(context, "initialized", json.Value{
                .object = json.ObjectMap.init(context.allocator),
            });
            try openAllFiles(context);
        }
    }

    // Handle diagnostic notifications
    if (msg_obj.get("method")) |method| {
        if (std.mem.eql(u8, method.string, "textDocument/publishDiagnostics")) {
            if (msg_obj.get("params")) |params| {
                try handleDiagnostics(context, params);
                context.diagnostics_received += 1;
            }
        }
    }
}

fn handleDiagnostics(context: *MessageContext, params: json.Value) !void {
    _ = context;
    const params_obj = params.object;
    const uri = params_obj.get("uri").?.string;
    const diagnostics_array = params_obj.get("diagnostics").?.array;

    // Extract file path from URI
    const file_path = if (std.mem.startsWith(u8, uri, "file://"))
        uri[7..]
    else
        uri;

    // Convert to relative path or basename for GitHub Actions
    const file_name = std.fs.path.basename(file_path);

    for (diagnostics_array.items) |diagnostic| {
        const diag_obj = diagnostic.object;
        const severity = diag_obj.get("severity").?.integer;
        const message_text = diag_obj.get("message").?.string;
        const range = diag_obj.get("range").?.object;

        const start_line = range.get("start").?.object.get("line").?.integer + 1;
        const end_line = range.get("end").?.object.get("line").?.integer + 1;

        // Map LSP severity to GitHub Actions severity
        const gh_type_and_title = switch (severity) {
            1 => .{ "error", "Error" },
            2 => .{ "warning", "Warning" },
            3 => .{ "notice", "Info" },
            4 => .{ "notice", "Hint" },
            else => .{ "notice", "Issue" },
        };
        const gh_type = gh_type_and_title[0];
        const title = gh_type_and_title[1];

        const stdout = std.io.getStdOut().writer();
        try stdout.print("::{s} file={s},line={d},endLine={d},title={s}::{s}\n", .{
            gh_type,
            file_name,
            start_line,
            end_line,
            title,
            message_text,
        });
    }
}

fn openAllFiles(context: *MessageContext) !void {
    for (context.files.items) |file_path| {
        const file_content = std.fs.cwd().readFileAlloc(context.allocator, file_path, 10 * 1024 * 1024) catch |err| {
            std.log.err("Failed to read file {s}: {}", .{ file_path, err });
            continue;
        };
        defer context.allocator.free(file_content);

        const language_id = determineLanguageId(std.fs.path.extension(file_path));

        var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
        const cwd = std.posix.getcwd(&cwd_buf) catch {
            std.log.err("Failed to get current working directory", .{});
            continue;
        };

        const absolute_path = if (std.fs.path.isAbsolute(file_path))
            file_path
        else
            try std.fs.path.join(context.allocator, &.{ cwd, file_path });
        defer if (!std.fs.path.isAbsolute(file_path)) context.allocator.free(absolute_path);

        const file_uri = try std.fmt.allocPrint(context.allocator, "file://{s}", .{absolute_path});
        defer context.allocator.free(file_uri);

        try sendDidOpen(context, file_uri, language_id, file_content);
        context.files_opened += 1;

        std.log.debug("Opened file: {s}", .{file_path});
    }
}

fn sendInitialize(context: *MessageContext) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var text_document_caps = json.ObjectMap.init(arena_allocator);
    var diagnostic_caps = json.ObjectMap.init(arena_allocator);
    try diagnostic_caps.put("dynamicRegistration", json.Value{ .bool = true });
    try diagnostic_caps.put("relatedDocumentSupport", json.Value{ .bool = true });
    try text_document_caps.put("diagnostic", json.Value{ .object = diagnostic_caps });

    var publish_diagnostic_caps = json.ObjectMap.init(arena_allocator);
    try publish_diagnostic_caps.put("relatedInformation", json.Value{ .bool = true });
    try publish_diagnostic_caps.put("versionSupport", json.Value{ .bool = true });
    try text_document_caps.put("publishDiagnostics", json.Value{ .object = publish_diagnostic_caps });

    var capabilities = json.ObjectMap.init(arena_allocator);
    try capabilities.put("textDocument", json.Value{ .object = text_document_caps });

    var client_info = json.ObjectMap.init(arena_allocator);
    try client_info.put("name", json.Value{ .string = "gh-lsp" });
    try client_info.put("version", json.Value{ .string = client_version });

    var params = json.ObjectMap.init(arena_allocator);
    try params.put("clientInfo", json.Value{ .object = client_info });
    try params.put("capabilities", json.Value{ .object = capabilities });

    var cwd_buf: [std.fs.max_path_bytes]u8 = undefined;
    const cwd = std.posix.getcwd(&cwd_buf) catch "./";
    const root_uri = try std.fmt.allocPrint(arena_allocator, "file://{s}", .{cwd});
    try params.put("rootUri", json.Value{ .string = root_uri });

    try sendRequest(context, "initialize", json.Value{ .object = params });
}

fn sendDidOpen(context: *MessageContext, uri: []const u8, language_id: []const u8, text: []const u8) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var text_document = json.ObjectMap.init(arena_allocator);
    try text_document.put("uri", json.Value{ .string = uri });
    try text_document.put("languageId", json.Value{ .string = language_id });
    try text_document.put("version", json.Value{ .integer = 1 });
    try text_document.put("text", json.Value{ .string = text });

    var params = json.ObjectMap.init(arena_allocator);
    try params.put("textDocument", json.Value{ .object = text_document });

    try sendNotification(context, "textDocument/didOpen", json.Value{ .object = params });
}

fn sendRequest(context: *MessageContext, method: []const u8, params: json.Value) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var request = json.ObjectMap.init(arena_allocator);
    try request.put("jsonrpc", json.Value{ .string = "2.0" });
    try request.put("id", json.Value{ .integer = message_id });
    try request.put("method", json.Value{ .string = method });
    try request.put("params", params);

    message_id += 1;

    try sendJsonRpc(context, json.Value{ .object = request });
}

fn sendNotification(context: *MessageContext, method: []const u8, params: json.Value) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var notification = json.ObjectMap.init(arena_allocator);
    try notification.put("jsonrpc", json.Value{ .string = "2.0" });
    try notification.put("method", json.Value{ .string = method });
    try notification.put("params", params);

    try sendJsonRpc(context, json.Value{ .object = notification });
}

fn sendShutdown(context: *MessageContext) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var request = json.ObjectMap.init(arena_allocator);
    try request.put("jsonrpc", json.Value{ .string = "2.0" });
    try request.put("id", json.Value{ .integer = message_id });
    try request.put("method", json.Value{ .string = "shutdown" });

    message_id += 1;

    try sendJsonRpc(context, json.Value{ .object = request });
}

fn sendExit(context: *MessageContext) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var notification = json.ObjectMap.init(arena_allocator);
    try notification.put("jsonrpc", json.Value{ .string = "2.0" });
    try notification.put("method", json.Value{ .string = "exit" });

    try sendJsonRpc(context, json.Value{ .object = notification });
}

fn sendJsonRpc(context: *MessageContext, value: json.Value) !void {
    var arena = std.heap.ArenaAllocator.init(context.allocator);
    defer arena.deinit();
    const arena_allocator = arena.allocator();

    var buffer = ArrayList(u8).init(arena_allocator);
    try json.stringify(value, .{}, buffer.writer());

    const content = try buffer.toOwnedSlice();
    const writer = context.stdin.writer();

    try writer.print("Content-Length: {d}\r\n\r\n", .{content.len});
    try writer.writeAll(content);

    std.log.debug("[CLIENT] {s}", .{content});
}

fn determineLanguageId(extension: []const u8) []const u8 {
    if (std.mem.eql(u8, extension, ".zig")) return "zig";
    if (std.mem.eql(u8, extension, ".c")) return "c";
    if (std.mem.eql(u8, extension, ".cpp") or std.mem.eql(u8, extension, ".cc") or
        std.mem.eql(u8, extension, ".cxx") or std.mem.eql(u8, extension, ".c++")) return "cpp";
    if (std.mem.eql(u8, extension, ".h") or std.mem.eql(u8, extension, ".hpp") or
        std.mem.eql(u8, extension, ".hxx")) return "c"; // or "cpp" depending on context
    if (std.mem.eql(u8, extension, ".js")) return "javascript";
    if (std.mem.eql(u8, extension, ".ts")) return "typescript";
    if (std.mem.eql(u8, extension, ".py")) return "python";
    if (std.mem.eql(u8, extension, ".rs")) return "rust";
    if (std.mem.eql(u8, extension, ".go")) return "go";
    if (std.mem.eql(u8, extension, ".java")) return "java";
    if (std.mem.eql(u8, extension, ".cs")) return "csharp";
    if (std.mem.eql(u8, extension, ".php")) return "php";
    if (std.mem.eql(u8, extension, ".rb")) return "ruby";
    if (std.mem.eql(u8, extension, ".swift")) return "swift";
    if (std.mem.eql(u8, extension, ".kt")) return "kotlin";
    if (std.mem.eql(u8, extension, ".scala")) return "scala";
    if (std.mem.eql(u8, extension, ".sh")) return "shellscript";
    if (std.mem.eql(u8, extension, ".json")) return "json";
    if (std.mem.eql(u8, extension, ".xml")) return "xml";
    if (std.mem.eql(u8, extension, ".html")) return "html";
    if (std.mem.eql(u8, extension, ".css")) return "css";
    return "plaintext";
}
