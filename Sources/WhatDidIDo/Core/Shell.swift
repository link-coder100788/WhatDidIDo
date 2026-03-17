import Foundation

enum Shell {
	case zsh
	case bash
	case fish
	case powershell
}

extension Shell {
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

	func toString() -> String {
		switch self {
		case .bash: return "Bash"
		case .fish: return "Fish"
		case .powershell: return "PowerShell"
		case .zsh: return "zsh"
		}
	}
}

