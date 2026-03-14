import ArgumentParser
import Foundation

// MARK: - Root Command

@main
struct WhatDidIDo: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "whatdidido",
		abstract: "A pretty wrapper for your shell history.",
		usage: "whatdidido <command> [options]",
		subcommands: [
			Recent.self,
			Dirs.self,
			Top.self,
			Search.self,
			For.self,
			Summary.self,
			Check.self,
			After.self,
			Config.self,
			Debug.self,
			Version.self,
			CheckUpdate.self,
		],
		defaultSubcommand: Recent.self
	)
}

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

func autoDetectOS() -> String {
#if os(macOS)
	return "macos"
#elseif os(Linux)
	return "linux"
#else
	return "windows"
#endif
}

func loadHistory(options: ShellOptions) throws -> History {
	WhatDidIDoConfigCore().load()
	let shell = try options.resolvedShell()
	let os = try options.resolvedOS()
	guard let history = HistoryReader().readHistory(os: os, shell: shell) else {
		throw ValidationError("Could not read history file. Check your shell/OS or set a custom path with `whatdidido config set --path`.")
	}
	return history
}

func printLines(_ lines: [String]) {
	lines.forEach { print($0) }
}

// MARK: - Recent

struct Recent: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Show what you just did — commands from your current session."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Option(name: .shortAndLong, help: "Number of commands to show.")
	var count: Int = 20

	func run() throws {
		embeddedUpdateCheck()
		
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).recent(count)
		printLines(lines)
	}
}

// MARK: - Dirs

struct Dirs: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Show the most recently visited directories (cd history)."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Option(name: .shortAndLong, help: "Number of directories to show.")
	var limit: Int = 10

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).recentDirectories(limit: limit)
		if lines.isEmpty {
			print("No cd commands found in history.")
		} else {
			printLines(lines)
		}
	}
}

// MARK: - Top

struct Top: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Show your most-used commands ranked by frequency."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Option(name: .shortAndLong, help: "How many top commands to show.")
	var count: Int = 10

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).mostUsed(top: count)
		printLines(lines)
	}
}

// MARK: - Search

struct Search: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Search your history for a keyword or phrase."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Argument(help: "The term to search for.")
	var query: String

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).search(query)
		if lines.isEmpty {
			print("No results for '\(query)'.")
		} else {
			printLines(lines)
		}
	}
}

// MARK: - For

struct For: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "for",
		abstract: "Show all commands you've used for a specific tool (e.g. git, docker, npm)."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Argument(help: "The tool/command name to filter by (e.g. git, docker, kubectl).")
	var tool: String

	@Option(name: .shortAndLong, help: "Max results to show.")
	var limit: Int = 20

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).commandsFor(tool, limit: limit)
		if lines.isEmpty {
			print("No '\(tool)' commands found in history.")
		} else {
			printLines(lines)
		}
	}
}

// MARK: - Summary

struct Summary: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "A de-duplicated digest of what you've been doing — great for standup notes."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Option(name: .shortAndLong, help: "How many recent commands to summarize.")
	var last: Int = 50

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).summary(last: last)
		printLines(lines)
	}
}

// MARK: - Check

struct Check: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Check if you've previously run a command."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Argument(help: "The command to check for.")
	var command: String

	@Flag(name: .long, help: "Require an exact match instead of a prefix match.")
	var exact: Bool = false

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let found = HistoryParser(history: history).hasPreviouslyRun(command, exact: exact)
		if found {
			print("✔ Yes, you've run '\(command)' before.")
		} else {
			print("✘ No previous run of '\(command)' found.")
		}
	}
}

// MARK: - After

struct After: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Show what you ran right after a matched command — useful for workflow recall."
	)

	@OptionGroup var shellOpts: ShellOptions

	@Argument(help: "The command or keyword to look up.")
	var query: String

	@Option(name: .shortAndLong, help: "How many subsequent commands to show.")
	var window: Int = 5

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).commandsAfter(query, window: window)
		if lines.isEmpty {
			print("'\(query)' not found, or nothing came after it.")
		} else {
			printLines(lines)
		}
	}
}

// MARK: - Config

struct Config: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "View or update your whatdidido configuration.",
		subcommands: [ConfigSet.self, ConfigShow.self, ConfigReset.self]
	)
}

struct ConfigSet: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "set",
		abstract: "Set a config value."
	)

	@Option(name: .long, help: "Custom path to your history file.")
	var path: String?

	@Option(name: .long, help: "Enable or disable color output (true/false).")
	var color: Bool?
	
	@Option(name: .long, help: "Enable warnings regarding if there is an available update.")
	var updateWarn: Bool?

	func run() throws {
		WhatDidIDoConfigCore().load()

		if let path = path {
			WhatDidIDoConfig.shared.customPath = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
			print("✔ Custom history path set to: \(path)")
		}

		if let color = color {
			WhatDidIDoConfig.shared.shouldColor = color
			print("✔ Color output set to: \(color)")
		}
		
		if let updateWarn = updateWarn {
			WhatDidIDoConfig.shared.updateAvailableWarning = updateWarn
			print("✔ Update warning set to: \(updateWarn)")
		}

		if path == nil && color == nil && updateWarn == nil {
			print("Nothing to set. Use --path, --color, or --updateWarn")
			return
		}

		WhatDidIDoConfigCore().save()
	}
}

struct ConfigShow: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "show",
		abstract: "Print your current configuration."
	)

	func run() {
		WhatDidIDoConfigCore().load()
		let cfg = WhatDidIDoConfig.shared
		print("color: \(cfg.shouldColor)")
		print("path: \(cfg.customPath?.path ?? "(default — auto-detected from shell)")")
		print("updateReminders: \(cfg.updateAvailableWarning)")
	}
}

struct ConfigReset: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "reset",
		abstract: "Reset configuration to defaults."
	)

	func run() throws {
		WhatDidIDoConfig.shared.customPath = nil
		WhatDidIDoConfig.shared.shouldColor = true
		WhatDidIDoConfigCore().save()
		print("✔ Configuration reset to defaults.")
	}
}

// MARK: - Debug

struct Debug: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Show auto-detected environment and operating system info."
	)

	@OptionGroup var shellOpts: ShellOptions

	func run() throws {
		WhatDidIDoConfigCore().load()
		let shell = try shellOpts.resolvedShell()
		let os = try shellOpts.resolvedOS()
		let historyURL = WhatDidIDoConfig.shared.customPath ?? shell.getDefaultDirectory(in: os)

		print("shell: \(shell.toString())")
		print("os: \(os.toString())")
		print("history: \(historyURL.path)")
		print("color: \(WhatDidIDoConfig.shared.shouldColor)")
	}
}

// MARK: - Version

struct Version: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Print the current version."
	)

	func run() {
		print("whatdidido \(Info.currentVersion)")
	}
}

// MARK: - Latest

struct CheckUpdate: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "check-update",
		abstract: "Check if a newer version is available on GitHub."
	)

	mutating func run() throws {
		if #available(macOS 12.0, *) {
			let sema = DispatchSemaphore(value: 0)
			
			Task {
				defer { sema.signal() }
				do {
					let result = try await VersionChecker.checkForUpdate(
						owner: Info.owner,
						repo: Info.repo,
						currentVersion: Info.currentVersion
					)
					
					if result.updateAvailable {
						print("Update available: \(result.latestVersion) (you have \(result.currentVersion))")
					} else {
						print("Up to date: \(result.currentVersion)")
					}
				} catch {
					print("\(TerminalColor().red) Error checking for update: \(error) \(TerminalColor().reset)")
				}
			}
			
			sema.wait()
		} else {
			print("\(TerminalColor().red) check-update requires macOS 12.0 or newer. \(TerminalColor().reset)")
		}
	}
}
