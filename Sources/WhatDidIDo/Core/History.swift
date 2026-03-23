import Foundation

// MARK: - History

/// A snapshot of a user's shell history for a specific shell and operating system.
struct History {
	/// The shell this history was read from.
	var shell: Shell

	/// The operating system this history was read from.
	var os: OperatingSystem

	/// The sanitised command lines in chronological order (oldest first).
	var content: [String]

	/// The most recently recorded command, or `"Error"` if the history is empty.
	var latestCommand: String {
		return content.last ?? "Error"
	}
}

// MARK: - HistoryReader

/// Reads and sanitises a shell history file from disk.
struct HistoryReader {
	/// Strips shell-specific metadata from a raw history line, returning the bare command string.
	///
	/// Different shells store additional data alongside commands:
	///
	/// - **zsh** (extended history): `": <timestamp>:<elapsed>;<command>"` — everything before and
	///   including the first `;` is removed.
	/// - **fish**: YAML-style entries beginning with `"- cmd: "` — the prefix is stripped; any other
	///   line (e.g. `when:` entries) is discarded by returning an empty string.
	/// - **bash / PowerShell**: Lines are returned trimmed with no further processing.
	///
	/// - Parameters:
	///   - line: A single raw line from the history file.
	///   - shell: The shell whose format should be applied when sanitising.
	/// - Returns: The sanitised command string, or an empty string if the line carries no command.
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

	/// Reads the history file for the given shell and OS, sanitises each line, and returns a ``History``.
	///
	/// The path is resolved in this order:
	/// 1. ``WhatDidIDoConfig/customPath`` if the user has set one.
	/// 2. The shell's platform-specific default path via ``Shell/getDefaultDirectory(in:)``.
	///
	/// The file is first decoded as UTF-8; if that fails, ISO Latin-1 is tried as a fallback
	/// (common for older zsh history files that contain non-UTF-8 bytes).
	///
	/// - Parameters:
	///   - os: The target operating system, used to resolve the default history path.
	///   - shell: The shell whose history format should be used.
	/// - Returns: A ``History`` value, or `nil` if the file could not be read.
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

// MARK: - HistoryParser

/// Transforms a ``History`` value into formatted, human-readable output lines.
///
/// Each method answers a specific question a developer might ask about their terminal
/// activity. Output lines include ANSI colour codes when ``WhatDidIDoConfig/shouldColor``
/// is `true`.
struct HistoryParser {
	/// The history to parse.
	let history: History

	/// Colour helper for applying ANSI escape codes.
	let color = TerminalColor()

	/// Returns `lines` with 1-based sequence numbers prepended, optionally offset by `offset`.
	///
	/// Numbers are right-aligned in a 4-character field and rendered in dim colour.
	///
	/// - Parameters:
	///   - lines: The command strings to number.
	///   - offset: Added to each line's 1-based index. Defaults to `0`.
	/// - Returns: The numbered strings.
	private func numbered(_ lines: [String], startingAt offset: Int = 0) -> [String] {
		lines.enumerated().map { i, line in
			"\(color.dim)\(String(format: "%4d", i + 1 + offset))\(color.reset)  \(line)"
		}
	}

	/// Returns the most recent `count` commands from the history, skipping session-break
	/// commands such as `clear`, `exit`, `reset`, and `logout`.
	///
	/// Line numbers reflect position in the original history, not in the returned slice,
	/// so they can be used as a stable reference.
	///
	/// - Parameter count: Maximum number of commands to return. Defaults to `20`.
	/// - Returns: Numbered, formatted command strings.
	func recent(_ count: Int = 20) -> [String] {
		let sessionBreakers: Set<String> = ["clear", "exit", "reset", "logout"]
		let filtered = history.content.filter { !sessionBreakers.contains($0.lowercased()) }
		let slice = Array(filtered.suffix(count))
		let base = max(0, history.content.count - slice.count)
		return numbered(slice, startingAt: base)
	}

	/// Returns the `limit` most recently visited unique directories extracted from `cd` commands.
	///
	/// Directories are deduplicated (keeping the most recent occurrence) and formatted with
	/// a cyan `cd` prefix for readability.
	///
	/// - Parameter limit: Maximum number of directories to return. Defaults to `10`.
	/// - Returns: Formatted `cd <path>` strings, newest last.
	func recentDirectories(limit: Int = 10) -> [String] {
		let cdPattern = #"^cd\s+"#
		let dirs = history.content
			.filter { $0.range(of: cdPattern, options: .regularExpression) != nil }
			.map { $0.replacingOccurrences(of: #"^cd\s+"#, with: "", options: .regularExpression) }
		var seen = Set<String>()
		let unique = dirs.reversed().filter { seen.insert($0).inserted }.reversed()
		return Array(unique.suffix(limit)).map { "\(color.cyan)cd\(color.reset) \($0)" }
	}

	/// Returns the top `n` commands ranked by use frequency, with a proportional ASCII bar chart.
	///
	/// Only the base command (first whitespace-delimited token) is counted, so
	/// `git status` and `git push` both contribute to the `git` tally.
	///
	/// Bar width is normalised to a maximum of 20 characters; each bar is rendered in yellow.
	///
	/// - Parameter n: Number of top commands to return. Defaults to `10`.
	/// - Returns: Ranked, formatted strings including rank, bar, command name, and count.
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

	/// Searches the full history for lines containing `query` (case-insensitive) and returns
	/// them with the matched substring highlighted in bold green.
	///
	/// Each result is prefixed with its 1-based line number in the original history.
	///
	/// - Parameter query: The search term to look for.
	/// - Returns: Matching lines with highlights and line numbers, or an empty array if there are no matches.
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

	/// Returns the last `limit` commands whose base command exactly matches `tool`.
	///
	/// Comparison is case-insensitive and matches the first whitespace-delimited token only,
	/// so `commandsFor("git")` will match `git status` but not `git-lfs`.
	///
	/// - Parameters:
	///   - tool: The tool name to filter by (e.g. `"git"`, `"docker"`, `"kubectl"`).
	///   - limit: Maximum number of results to return. Defaults to `20`.
	/// - Returns: Numbered, cyan-tinted command strings.
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

	/// Returns a de-duplicated digest of the last `count` history entries.
	///
	/// Only the first occurrence of each unique base command is kept (in order), making the
	/// output suitable as standup notes or a quick activity recap.
	///
	/// Each line is prefixed with a blue `▸` arrow.
	///
	/// - Parameter count: How many recent history entries to consider. Defaults to `50`.
	/// - Returns: De-duplicated, formatted command strings.
	func summary(last count: Int = 50) -> [String] {
		var seen = Set<String>()
		let unique = history.content.suffix(count).filter { line in
			let base = line.components(separatedBy: .whitespaces).first ?? line
			return seen.insert(base).inserted
		}
		return unique.map { "\(color.blue)▸\(color.reset) \($0)" }
	}

	/// Returns `true` if `command` appears somewhere in the history (excluding the very last
	/// entry, which is typically the `whatdidido` invocation itself).
	///
	/// - Parameters:
	///   - command: The command string to search for.
	///   - exact: When `true`, the full command string must match exactly. When `false` (the
	///     default), only the base command token is compared.
	/// - Returns: `true` if a matching entry was found.
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

	/// Returns the `window` commands that immediately followed the last occurrence of `query`
	/// in the history.
	///
	/// This is useful for reconstructing multi-step workflows you can only half-remember
	/// (e.g. "what did I run right after cloning that repo?").
	///
	/// - Parameters:
	///   - query: The command or keyword to locate (case-insensitive substring match).
	///   - window: How many subsequent commands to return. Defaults to `5`.
	/// - Returns: The following commands prefixed with a blue `▸` arrow, or an empty array
	///   if `query` was not found or nothing followed it.
	func commandsAfter(_ query: String, window: Int = 5) -> [String] {
		guard let idx = history.content.lastIndex(where: {
			$0.localizedCaseInsensitiveContains(query)
		}) else { return [] }
		let start = history.content.index(after: idx)
		let end = min(history.content.index(start, offsetBy: window), history.content.endIndex)
		return Array(history.content[start..<end]).map { "\(color.blue)▸\(color.reset) \($0)" }
	}
}
