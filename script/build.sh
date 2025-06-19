#!/usr/bin/env bash
# https://github.com/cli/gh-extension-precompile?tab=readme-ov-file#extensions-written-in-other-compiled-languages
# The build script will receive the release tag name as the first argument.
#
# It should build binaries in dist/<platform>-<arch>[.exe] as needed.
#
# Locally on MacOS I needed to link the libSystem to the current version of zig
# ZIG_VERSION="$(brew info zig | grep "^/opt/homebrew/Cellar/zig/" | cut -d" " -f1)"
# ln -s /Applications/Xcode.app//Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk/usr/lib/libSystem.B.tbd /opt/homebrew/Cellar/zig/${ZIG_VERSION}/lib/zig/libc/darwin/libSystem.tbd
(
	cd "$(git rev-parse --show-toplevel)" || exit 1
	mkdir -p dist

	for os in macos linux windows; do
		ext=""
		if [[ "$os" == "windows" ]]; then
			ext=".exe"
		fi
		for arch in aarch64 x86_64; do
			echo "Building for $os/$arch"
			zig build -Dtarget=$arch-$os && cp "./zig-out/bin/gh-lsp${ext}" "./dist/gh-lsp-${os}-${arch}${ext}"
		done
	done
	echo "Built following files:"
	file dist/*
)
