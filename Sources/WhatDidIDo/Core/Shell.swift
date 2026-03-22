import Foundation

// MARK: - Shell

/// The supported interactive shells that `whatdidido` can read history from.
enum Shell {
	/// Z shell — history stored in `~/.zsh_history`, optionally with extended timestamp metadata.
	case zsh
	/// Bourne-Again shell — history stored in `~/.bash_history`.
	case bash
	/// Fish shell — history stored in `~/.local/share/fish/fish_history` as YAML.
	case fish
	/// PowerShell — history stored at a platform-specific `PSReadLine` path.
	case powershell
}

extension Shell {
	/// Returns the default history file URL for this shell on the given operating system.
	///
	/// When ``WhatDidIDoConfig/customPath`` is set, callers should use that value instead.
	///
	/// | Shell       | macOS                                                              | Linux                                               | Windows                                                        |
	/// |-------------|--------------------------------------------------------------------|-----------------------------------------------------|----------------------------------------------------------------|
	/// | zsh         | `~/.zsh_history`                                                   | `~/.zsh_history`                                    | n/a                                                            |
	/// | bash        | `~/.bash_history`                                                  | `~/.bash_history`                                   | n/a                                                            |
	/// | fish        | `~/.local/share/fish/fish_history`                                 | `~/.local/share/fish/fish_history`                  | n/a                                                            |
	/// | powershell  | `~/Library/Application Support/PowerShell/PSReadLine/…`           | `~/.local/share/powershell/PSReadLine/…`            | `~/AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/…` |
	///
	/// - Parameter os: The operating system to resolve the path for.
	/// - Returns: The `URL` of the default history file.
	func getDefaultDirectory(in os: OperatingSystem) -> URL {
		let home = FileManager.default.homeDirectoryForCurrentUser

		switch (os, self) {
		case (.windows, .powershell):
			return home.appendingPathComponent("AppData/Roaming/Microsoft/Windows/PowerShell/PSReadLine/ConsoleHost_history.txt")
		case (.macOS, .powershell):
			return home.appendingPathComponent("Library/Application Support/PowerShell/PSReadLine/ConsoleHost_history.txt")
		case (_, .zsh):
			return home.appendingPathComponent(".zsh_history")
		case (_, .bash):
			return home.appendingPathComponent(".bash_history")
		case (_, .fish):
			return home.appendingPathComponent(".local/share/fish/fish_history")
		case (_, .powershell):
			return home.appendingPathComponent(".local/share/powershell/PSReadLine/ConsoleHost_history.txt")
		}
	}

	/// A human-readable display name for this shell (e.g. `"zsh"`, `"Bash"`).
	func toString() -> String {
		switch self {
		case .bash:       return "Bash"
		case .fish:       return "Fish"
		case .powershell: return "PowerShell"
		case .zsh:        return "zsh"
		}
	}
}
