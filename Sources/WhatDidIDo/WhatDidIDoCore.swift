import Foundation

enum Shell {
	case zsh
	case bash
	case fish
	case powershell
}

enum OperatingSystem {
	case macOS
	case linux
	case windows
}

extension OperatingSystem {
	func toString() -> String {
		switch self {
		case .linux: return "Linux"
		case .macOS: return "MacOS"
		case .windows: return "Windows"
		}
	}
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

struct History {
	var shell: Shell
	var os: OperatingSystem
	var content: [String]

	var latestCommand: String {
		return content.last ?? "Error"
	}
}

struct HistoryReader {
	func sanitize(_ line: String, for shell: Shell) -> String {
		let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

		switch shell {
		case .zsh:
			// zsh extended history format: ": <timestamp>:<elapsed>;<command>"
			let components = trimmed.components(separatedBy: ";")
			if components.count > 1 {
				return components.dropFirst().joined(separator: ";")
			}
			return trimmed

		case .fish:
			// Fish history format:
			//   - cmd: <command>
			//     when: <timestamp>
			// Only extract lines starting with "- cmd: "
			if trimmed.hasPrefix("- cmd: ") {
				return String(trimmed.dropFirst("- cmd: ".count))
			}
			return ""

		default:
			return trimmed
		}
	}

	func readHistory(os: OperatingSystem, shell: Shell) -> History? {
		let url = WhatDidIDoConfig.shared.customPath ?? shell.getDefaultDirectory(in: os)

		let contents: String?
		if let data = try? Data(contentsOf: url) {
			contents = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1)
		} else {
			contents = nil
		}

		guard let contents = contents else {
			print("Error: Could not read history at \(url.path)")
			return nil
		}

		let lines = contents.components(separatedBy: .newlines)
			.map { sanitize($0, for: shell) }
			.filter { !$0.isEmpty }

		return History(shell: shell, os: os, content: lines)
	}
}

struct WhatDidIDoConfig {
	nonisolated(unsafe) static var shared = WhatDidIDoConfig()

	var customPath: URL? = nil
	var shouldColor: Bool = true
}

struct WhatDidIDoConfigCodable: Encodable, Decodable {
	var customPath: URL?
	var shouldColor: Bool

	static func from(config: WhatDidIDoConfig) -> WhatDidIDoConfigCodable {
		return WhatDidIDoConfigCodable(customPath: config.customPath, shouldColor: config.shouldColor)
	}
}

struct WhatDidIDoConfigCore {
	private var configURL: URL {
		FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido/config.plist")
	}

	private func ensureConfigDirectoryExists() {
		let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido")
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
	}

	func save() {
		ensureConfigDirectoryExists()
		let plistEncoder = PropertyListEncoder()
		let toEncode = WhatDidIDoConfigCodable.from(config: WhatDidIDoConfig.shared)
		guard let encoded = try? plistEncoder.encode(toEncode) else { return }
		try? encoded.write(to: configURL)
	}

	func load() {
		guard let encoded = try? Data(contentsOf: configURL) else { return }
		let plistDecoder = PropertyListDecoder()
		guard let decoded = try? plistDecoder.decode(WhatDidIDoConfigCodable.self, from: encoded) else { return }

		WhatDidIDoConfig.shared.customPath = decoded.customPath
		WhatDidIDoConfig.shared.shouldColor = decoded.shouldColor
	}
}

struct HistoryParser {
	let history: History

	// MARK: - Color Helpers

	private func color(_ code: String) -> String {
		return WhatDidIDoConfig.shared.shouldColor ? code : ""
	}

	private var green: String  { color("\u{001B}[32m") }
	private var cyan: String   { color("\u{001B}[36m") }
	private var yellow: String { color("\u{001B}[33m") }
	private var blue: String   { color("\u{001B}[34m") }
	private var bold: String   { color("\u{001B}[1m") }
	private var dim: String    { color("\u{001B}[2m") }
	private var reset: String  { color("\u{001B}[0m") }

	private func numbered(_ lines: [String], startingAt offset: Int = 0) -> [String] {
		lines.enumerated().map { i, line in
			"\(dim)\(String(format: "%4d", i + 1 + offset))\(reset)  \(line)"
		}
	}

	// MARK: - Daily Drivers

	/// "What did I just do?" — commands since the last clear/exit, or last N
	func recent(_ count: Int = 20) -> [String] {
		let sessionBreakers = ["clear", "exit", "reset", "logout"]
		let session: [String]
		if let lastBreak = history.content.lastIndex(where: { sessionBreakers.contains($0.lowercased()) }) {
			session = Array(history.content.suffix(from: lastBreak + 1))
		} else {
			session = history.content
		}
		let slice = Array(session.suffix(count))
		let base = max(0, history.content.count - slice.count)
		return numbered(slice, startingAt: base)
	}

	/// "Where was I working?" — most recently visited directories
	func recentDirectories(limit: Int = 10) -> [String] {
		let cdPattern = #"^cd\s+"#
		let dirs = history.content
			.filter { $0.range(of: cdPattern, options: .regularExpression) != nil }
			.map { $0.replacingOccurrences(of: #"^cd\s+"#, with: "", options: .regularExpression) }
		var seen = Set<String>()
		let unique = dirs.reversed().filter { seen.insert($0).inserted }.reversed()
		return Array(unique.suffix(limit)).map { "\(cyan)cd\(reset) \($0)" }
	}

	/// "What commands do I use most?" — ranked frequency table
	func mostUsed(top n: Int = 10) -> [String] {
		var freq: [String: Int] = [:]
		for cmd in history.content {
			let base = cmd.components(separatedBy: .whitespaces).first ?? cmd
			freq[base, default: 0] += 1
		}
		let sorted = freq.sorted { $0.value > $1.value }.prefix(n)
		let maxCount = sorted.first?.value ?? 1
		return sorted.enumerated().map { i, pair in
			let bar = String(repeating: "▪", count: max(1, pair.value * 20 / maxCount))
			return "\(bold)\(String(format: "%2d", i + 1))\(reset)  \(yellow)\(bar)\(reset)  \(pair.key) \(dim)(\(pair.value)x)\(reset)"
		}
	}

	/// "Did I already do this?" — search with highlighted matches
	func search(_ query: String) -> [String] {
		let matches = history.content.enumerated().filter {
			$0.element.localizedCaseInsensitiveContains(query)
		}
		return matches.map { i, line in
			let highlighted = WhatDidIDoConfig.shared.shouldColor
				? line.replacingOccurrences(of: query, with: "\(bold)\(green)\(query)\(reset)", options: .caseInsensitive)
				: line
			return "\(dim)\(String(format: "%4d", i + 1))\(reset)  \(highlighted)"
		}
	}

	/// "How do I do X again?" — find commands matching a tool/prefix (e.g. "git", "docker")
	func commandsFor(_ tool: String, limit: Int = 20) -> [String] {
		let prefix = tool.lowercased()
		let matches = history.content.enumerated().filter {
			let base = $0.element.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
			return base == prefix
		}
		return Array(matches.suffix(limit)).map { i, line in
			"\(dim)\(String(format: "%4d", i + 1))\(reset)  \(cyan)\(line)\(reset)"
		}
	}

	/// "What was I doing around a certain time?" — last N unique base commands as a readable summary
	func summary(last count: Int = 50) -> [String] {
		var seen = Set<String>()
		let unique = history.content.suffix(count).filter { line in
			let base = line.components(separatedBy: .whitespaces).first ?? line
			return seen.insert(base).inserted
		}
		return unique.map { "\(blue)▸\(reset) \($0)" }
	}

	/// "Did I ever run this exact thing before?" — check for an exact or prefix match.
	/// Note: always excludes the very last history entry, which is typically the `whatdidido` invocation itself.
	func hasPreviouslyRun(_ command: String, exact: Bool = false) -> Bool {
		if exact {
			return history.content.dropLast().contains(command)
		} else {
			let query = command.components(separatedBy: .whitespaces).first ?? command
			return history.content.dropLast().contains {
				($0.components(separatedBy: .whitespaces).first ?? "") == query
			}
		}
	}

	/// "What did I run after X?" — commands following a match, useful for workflow recall
	func commandsAfter(_ query: String, window: Int = 5) -> [String] {
		guard let idx = history.content.lastIndex(where: {
			$0.localizedCaseInsensitiveContains(query)
		}) else { return [] }
		let start = history.content.index(after: idx)
		let end = min(history.content.index(start, offsetBy: window), history.content.endIndex)
		return Array(history.content[start..<end]).map { "\(blue)▸\(reset) \($0)" }
	}
}
