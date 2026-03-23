import Foundation
import ArgumentParser

/// Returns the current operating system as a lowercase string identifier.
///
/// Uses compile-time `#if os(...)` directives, so the result is always accurate
/// for the platform the binary was compiled on.
///
/// - Returns: `"macos"`, `"linux"`, or `"windows"`.
func autoDetectOS() -> String {
#if os(macOS)
	return "macos"
#elseif os(Linux)
	return "linux"
#else
	return "windows"
#endif
}

/// Loads and returns the shell history for the environment described by `options`.
///
/// Internally this:
/// 1. Loads the persisted user config from disk.
/// 2. Resolves the shell and OS from `options` (or their auto-detected defaults).
/// 3. Reads the appropriate history file via ``HistoryReader``.
///
/// - Parameter options: The ``ShellOptions`` group that carries `--shell` and `--os` overrides.
/// - Returns: A ``History`` value containing the parsed command lines.
/// - Throws: `ArgumentParser/ValidationError` if the shell or OS string is unrecognised,
///   or if the history file cannot be located or read.
func loadHistory(options: ShellOptions) throws -> History {
	WhatDidIDoConfigCore().load()
	let shell = try options.resolvedShell()
	let os = try options.resolvedOS()
	guard let history = HistoryReader().readHistory(os: os, shell: shell) else {
		throw ValidationError("Could not read history file. Check your shell/OS or set a custom path with `whatdidido config set --path`.")
	}
	return history
}

/// Prints each string in `lines` to standard output, one per line.
///
/// This is a thin convenience wrapper around `Swift.print` used throughout the
/// command implementations to keep call-sites tidy.
///
/// - Parameter lines: The formatted strings to emit.
func printLines(_ lines: [String]) {
	lines.forEach { print($0) }
}
