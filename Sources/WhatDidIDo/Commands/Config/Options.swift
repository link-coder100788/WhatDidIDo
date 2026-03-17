import Foundation
import ArgumentParser

// MARK: - Shared Options

struct ShellOptions: ParsableArguments {
	@Option(name: .shortAndLong, help: "Shell to read history from (zsh, bash, fish, powershell).")
	var shell: String = autoDetectShell()

	@Option(name: .shortAndLong, help: "Operating system (macos, linux, windows).")
	var os: String = autoDetectOS()

	func resolvedShell() throws -> Shell {
		switch shell.lowercased() {
		case "zsh": return .zsh
		case "bash": return .bash
		case "fish": return .fish
		case "powershell": return .powershell
		default:
			throw ValidationError("Unknown shell '\(shell)'. Use: zsh, bash, fish, powershell")
		}
	}

	func resolvedOS() throws -> OperatingSystem {
		switch os.lowercased() {
		case "macos", "mac": return .macOS
		case "linux": return .linux
		case "windows": return .windows
		default:
			throw ValidationError("Unknown OS '\(os)'. Use: macos, linux, windows")
		}
	}
}

func autoDetectShell() -> String {
	if let shell = ProcessInfo.processInfo.environment["SHELL"] {
		if shell.contains("zsh") { return "zsh" }
		if shell.contains("bash") { return "bash" }
		if shell.contains("fish") { return "fish" }
	}
	return "zsh"
}
