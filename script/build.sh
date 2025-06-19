#!/usr/bin/env bash
# https://github.com/cli/gh-extension-precompile?tab=readme-ov-file#extensions-written-in-other-compiled-languages
# The build script will receive the release tag name as the first argument.
#
# It should build binaries in dist/<platform>-<arch>[.exe] as needed.
(
	cd "$(git rev-parse --show-toplevel)" || exit 1
	mkdir -p dist

	echo "Building aarch64-macos"
	zig build -Dtarget=aarch64-macos
	cp "./zig-out/bin/gh-lsp" "./dist/gh-lsp-darwin-arm64"

	echo "Building x86_64-macos"
	zig build -Dtarget=x86_64-macos
	cp "./zig-out/bin/gh-lsp" "./dist/gh-lsp-darwin-amd64"

	echo "Building aarch64-linux"
	zig build -Dtarget=aarch64-linux
	cp "./zig-out/bin/gh-lsp" "./dist/gh-lsp-linux-arm64"

	echo "Building x86_64-linux"
	zig build -Dtarget=x86_64-linux
	cp "./zig-out/bin/gh-lsp" "./dist/gh-lsp-linux-amd64"

	echo "Building x86_64-windows"
	zig build -Dtarget=x86_64-windows
	cp "./zig-out/bin/gh-lsp" "./dist/gh-lsp-windows-amd64"

	echo "Built following files:"
	file dist/*
)
