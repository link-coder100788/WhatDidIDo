import Foundation
import ArgumentParser

// MARK: - Shared Options

/// Reusable `@OptionGroup` that adds `--shell` and `--os` flags to any command.
///
/// Both options default to auto-detected values and rarely need to be supplied manually.
/// Include this group with `@OptionGroup var shellOpts: ShellOptions` in any
/// ``ParsableCommand`` that needs to read the history file.
struct ShellOptions: ParsableArguments {
	/// The shell to read history from.
	///
	/// Accepts `zsh`, `bash`, `fish`, or `powershell` (case-insensitive).
	/// Defaults to the value returned by ``autoDetectShell()``.
	@Option(name: .shortAndLong, help: "Shell to read history from (zsh, bash, fish, powershell).")
	var shell: String = autoDetectShell()

	/// The operating system to read history for.
	///
	/// Accepts `macos`, `mac`, `linux`, or `windows` (case-insensitive).
	/// Defaults to the value returned by ``autoDetectOS()``.
	@Option(name: .shortAndLong, help: "Operating system (macos, linux, windows).")
	var os: String = autoDetectOS()

	/// Converts the raw `--shell` string into a typed ``Shell`` value.
	///
	/// - Throws: ``ArgumentParser/ValidationError`` if the string is not a recognised shell name.
	func resolvedShell() throws -> Shell {
		switch shell.lowercased() {
		case "zsh":        return .zsh
		case "bash":       return .bash
		case "fish":       return .fish
		case "powershell": return .powershell
		default:
			throw ValidationError("Unknown shell '\(shell)'. Use: zsh, bash, fish, powershell")
		}
	}

	/// Converts the raw `--os` string into a typed ``OperatingSystem`` value.
	///
	/// - Throws: ``ArgumentParser/ValidationError`` if the string is not a recognised OS name.
	func resolvedOS() throws -> OperatingSystem {
		switch os.lowercased() {
		case "macos", "mac": return .macOS
		case "linux":        return .linux
		case "windows":      return .windows
		default:
			throw ValidationError("Unknown OS '\(os)'. Use: macos, linux, windows")
		}
	}
}

/// Infers the current shell from the `SHELL` environment variable.
///
/// Inspects `$SHELL` for the substrings `"zsh"`, `"bash"`, and `"fish"` in that order.
/// Falls back to `"zsh"` if the variable is unset or does not match a known shell.
///
/// - Returns: A lowercase shell identifier string suitable for ``ShellOptions``.
func autoDetectShell() -> String {
	if let shell = ProcessInfo.processInfo.environment["SHELL"] {
		if shell.contains("zsh")  { return "zsh" }
		if shell.contains("bash") { return "bash" }
		if shell.contains("fish") { return "fish" }
	}
	return "zsh"
}
