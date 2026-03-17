import Foundation

enum Info {
	static let owner = "link-coder100788"
	static let repo = "WhatDidIDo"
	static let currentVersion = "1.5.0"
}

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

// MARK: - Config

struct WhatDidIDoConfig {
	nonisolated(unsafe) static var shared = WhatDidIDoConfig()

	var customPath: URL? = nil
	var shouldColor: Bool = true
	var updateAvailableWarning: Bool = true
	var lastUpdateCheck: Date? = nil
	var checkUpdateTimeout: Int = 15
	var locale: Locale = Locale.current
	var summaryDate: Bool = true
}

struct WhatDidIDoConfigCodable: Encodable, Decodable {
	var customPath: URL?
	var shouldColor: Bool
	var updateAvailableWarning: Bool
	var lastUpdateCheck: Date?
	var checkUpdateTimeout: Int
	var locale: Locale
	var summaryDate: Bool

	static func from(config: WhatDidIDoConfig) -> WhatDidIDoConfigCodable {
		return WhatDidIDoConfigCodable(
			customPath: config.customPath,
			shouldColor: config.shouldColor,
			updateAvailableWarning: config.updateAvailableWarning,
			lastUpdateCheck: config.lastUpdateCheck,
			checkUpdateTimeout: config.checkUpdateTimeout,
			locale: config.locale,
			summaryDate: config.summaryDate,
		)
	}
}

struct WhatDidIDoConfigCore {
	var configURL: URL {
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
		WhatDidIDoConfig.shared.updateAvailableWarning = decoded.updateAvailableWarning
		WhatDidIDoConfig.shared.lastUpdateCheck = decoded.lastUpdateCheck
		WhatDidIDoConfig.shared.checkUpdateTimeout = decoded.checkUpdateTimeout
		WhatDidIDoConfig.shared.locale = decoded.locale
		WhatDidIDoConfig.shared.summaryDate = decoded.summaryDate
	}
}

typealias CFG = WhatDidIDoConfig

// MARK: - Color Helpers

struct TerminalColor {
	private func color(_ code: String) -> String {
		return WhatDidIDoConfig.shared.shouldColor ? code : ""
	}
	
	var red: String    { color("\u{001B}[31m") }
	var green: String  { color("\u{001B}[32m") }
	var cyan: String   { color("\u{001B}[36m") }
	var yellow: String { color("\u{001B}[33m") }
	var blue: String   { color("\u{001B}[34m") }
	var bold: String   { color("\u{001B}[1m") }
	var dim: String    { color("\u{001B}[2m") }
	var reset: String  { color("\u{001B}[0m") }
	
	enum Color {
		case red
		case green
		case cyan
		case yellow
		case blue
		case bold
		case dim
		case reset
		
		func getMarker() -> String {
			switch self {
			case .red:
				return TerminalColor().red
			case .blue:
				return TerminalColor().blue
			case .cyan:
				return TerminalColor().cyan
			case .yellow:
				return TerminalColor().yellow
			case .green:
				return TerminalColor().green
			case .bold:
				return TerminalColor().bold
			case .dim:
				return TerminalColor().dim
			case .reset:
				return TerminalColor().reset
			}
		}
	}
	
	static func applyColor(color: Color, to text: String) -> String {
		return "\(color.getMarker())\(text)\(TerminalColor().reset)"
	}
}

extension String {
	func color(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}
	
	func withColor(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}
}

struct HistoryParser {
	let history: History
	
	let color = TerminalColor()

	private func numbered(_ lines: [String], startingAt offset: Int = 0) -> [String] {
		lines.enumerated().map { i, line in
			"\(color.dim)\(String(format: "%4d", i + 1 + offset))\(color.reset)  \(line)"
		}
	}

	// MARK: - Daily Drivers

	/// "What did I just do?"  commands since the last clear/exit, or last N
	func recent(_ count: Int = 20) -> [String] {
		let sessionBreakers: Set<String> = ["clear", "exit", "reset", "logout"]
		let filtered = history.content.filter { !sessionBreakers.contains($0.lowercased()) }
		let slice = Array(filtered.suffix(count))
		let base = max(0, history.content.count - slice.count)
		return numbered(slice, startingAt: base)
	}

	/// "Where was I working?"  most recently visited directories
	func recentDirectories(limit: Int = 10) -> [String] {
		let cdPattern = #"^cd\s+"#
		let dirs = history.content
			.filter { $0.range(of: cdPattern, options: .regularExpression) != nil }
			.map { $0.replacingOccurrences(of: #"^cd\s+"#, with: "", options: .regularExpression) }
		var seen = Set<String>()
		let unique = dirs.reversed().filter { seen.insert($0).inserted }.reversed()
		return Array(unique.suffix(limit)).map { "\(color.cyan)cd\(color.reset) \($0)" }
	}

	/// "What commands do I use most?"  ranked frequency table
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
			return "\(color.bold)\(String(format: "%2d", i + 1))\(color.reset)  \(color.yellow)\(bar)\(color.reset)  \(pair.key) \(color.dim)(\(pair.value)x)\(color.reset)"
		}
	}

	/// "Did I already do this?"  search with highlighted matches
	func search(_ query: String) -> [String] {
		let matches = history.content.enumerated().filter {
			$0.element.localizedCaseInsensitiveContains(query)
		}
		return matches.map { i, line in
			let highlighted = WhatDidIDoConfig.shared.shouldColor
			? line.replacingOccurrences(of: query, with: "\(color.bold)\(color.green)\(query)\(color.reset)", options: .caseInsensitive)
				: line
			return "\(color.dim)\(String(format: "%4d", i + 1))\(color.reset)  \(highlighted)"
		}
	}

	/// "How do I do X again?"  find commands matching a tool/prefix (e.g. "git", "docker")
	func commandsFor(_ tool: String, limit: Int = 20) -> [String] {
		let prefix = tool.lowercased()
		let matches = history.content.enumerated().filter {
			let base = $0.element.components(separatedBy: .whitespaces).first?.lowercased() ?? ""
			return base == prefix
		}
		return Array(matches.suffix(limit)).map { i, line in
			"\(color.dim)\(String(format: "%4d", i + 1))\(color.reset)  \(color.cyan)\(line)\(color.reset)"
		}
	}

	/// "What was I doing around a certain time?"  last N unique base commands as a readable summary
	func summary(last count: Int = 50) -> [String] {
		var seen = Set<String>()
		let unique = history.content.suffix(count).filter { line in
			let base = line.components(separatedBy: .whitespaces).first ?? line
			return seen.insert(base).inserted
		}
		return unique.map { "\(color.blue)▸\(color.reset) \($0)" }
	}

	/// "Did I ever run this exact thing before?" check for an exact or prefix match.
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

	/// "What did I run after X?"  commands following a match, useful for workflow recall
	func commandsAfter(_ query: String, window: Int = 5) -> [String] {
		guard let idx = history.content.lastIndex(where: {
			$0.localizedCaseInsensitiveContains(query)
		}) else { return [] }
		let start = history.content.index(after: idx)
		let end = min(history.content.index(start, offsetBy: window), history.content.endIndex)
		return Array(history.content[start..<end]).map { "\(color.blue)▸\(color.reset) \($0)" }
	}
}

// MARK: - Latest Version Helper

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct UpdateResult {
	let currentVersion: String
	let latestVersion: String
	let updateAvailable: Bool
}

enum VersionError: Error, CustomStringConvertible {
	case networkError(statusCode: Int)
	case parseError
	case invalidVersion(String)
	case noNetwork
	case timedOut

	var description: String {
		switch self {
		case .networkError(let code): return "Network request failed with status code \(code)"
		case .parseError: return "Failed to parse GitHub API response"
		case .invalidVersion(let v): return "Invalid version string: \(v)"
		case .noNetwork: return "No network connection. Please check your internet and try again."
		case .timedOut: return "Request timed out. Please try again."
		}
	}
}

// MARK: - Version Logic

struct VersionChecker {
	static func isNewerVersion(_ latest: String, than current: String) -> Bool {
		let clean = { (v: String) in
			v.trimmingCharacters(in: .init(charactersIn: "v"))
			 .split(separator: ".").compactMap { Int($0) }
		}
		let latestParts = clean(latest)
		let currentParts = clean(current)
		let maxLength = max(latestParts.count, currentParts.count)
		let lPadded = latestParts + Array(repeating: 0, count: maxLength - latestParts.count)
		let cPadded = currentParts + Array(repeating: 0, count: maxLength - currentParts.count)

		for (l, c) in zip(lPadded, cPadded) {
			if l > c { return true }
			if l < c { return false }
		}
		return false
	}

	@available(macOS 12.0, *)
	static func fetchLatestVersion(owner: String, repo: String, token: String? = nil) async throws -> String {
		let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
		var request = URLRequest(url: url)
		request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
		request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
		if let token {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}

		let data: Data
		let response: URLResponse
		
		do {
			(data, response) = try await URLSession.shared.data(for: request)
		} catch let urlError as URLError {
			switch urlError.code {
			case .notConnectedToInternet: throw VersionError.noNetwork
			case .timedOut: throw VersionError.timedOut
			default: throw VersionError.networkError(statusCode: -1)
			}
		}

		guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
			let code = (response as? HTTPURLResponse)?.statusCode ?? -1
			throw VersionError.networkError(statusCode: code)
		}
		
		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let tag = json["tag_name"] as? String else {
			throw VersionError.parseError
		}
		
		return tag
	}

	@available(macOS 12.0, *)
	static func checkForUpdate(owner: String, repo: String, currentVersion: String, token: String? = nil) async throws -> UpdateResult {
		let latest = try await fetchLatestVersion(owner: owner, repo: repo, token: token)
		return UpdateResult(
			currentVersion: currentVersion,
			latestVersion: latest,
			updateAvailable: isNewerVersion(latest, than: currentVersion)
		)
	}
}

struct Helper {
	static func embeddedUpdateCheck() async {
		guard WhatDidIDoConfig.shared.updateAvailableWarning else { return }

		let checkInterval: TimeInterval = 60 * 60 * 24
		 
		if let last = WhatDidIDoConfig.shared.lastUpdateCheck,
		   Date().timeIntervalSince(last) < checkInterval {
			return
		}

		if #available(macOS 12.0, *) {
			do {
				let result = try await VersionChecker.checkForUpdate(
				 owner: Info.owner,
				 repo: Info.repo,
				 currentVersion: Info.currentVersion
				)
			 
				if result.updateAvailable {
					print("Update available: \(result.latestVersion) (you have \(result.currentVersion))")
					print("Disable these warnings with: whatdidido config --set updateWarn false")
				}
			 
				WhatDidIDoConfig.shared.lastUpdateCheck = Date()
				WhatDidIDoConfigCore().save()
				} catch { }
		 }
	}
	
	static func openConfigFolder(at url: URL) throws {
		let folderPath = url.deletingLastPathComponent().path
		
		let ps = Process()
		
		#if os(macOS)
		ps.executableURL = URL(fileURLWithPath: "/usr/bin/open")
		ps.arguments = [folderPath]
		#elseif os(Linux)
		// We try xdg-open
		ps.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
		ps.arguments = [folderPath]
		#elseif os(Windows)
		ps.executableURL = URL(fileURLWithPath: "cmd")
		ps.arguments = ["/c", "start", "", folderPath]
		#endif
		
		try ps.run()
	}
}
