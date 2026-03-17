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
			Completion.self,
			AISummary.self,
		]
	)
	
	@OptionGroup var shellOpts: ShellOptions
	
	@Option(name: .shortAndLong, help: "Number of commands to show.")
	var count: Int = 20

	func run() throws {
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).recent(count)
		printLines(lines)
		
		if #available(macOS 10.15, *) {
			let sema = DispatchSemaphore(value: 0)
			Task {
				await Helper.embeddedUpdateCheck()
				sema.signal()
			}
			sema.wait()
		}
	}
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
		let history = try loadHistory(options: shellOpts)
		let lines = HistoryParser(history: history).recent(count)
		printLines(lines)
		
		if #available(macOS 10.15, *) {
			let sema = DispatchSemaphore(value: 0)
			Task {
				await Helper.embeddedUpdateCheck()
				sema.signal()
			}
			sema.wait()
		}
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

		if WhatDidIDoConfig.shared.summaryDate {
			var dateFormatter = DateFormatter()
			
			dateFormatter.locale = WhatDidIDoConfig.shared.locale
			dateFormatter.setLocalizedDateFormatFromTemplate("MMMMdYYYY")
		
			print("Summary of last \(last) lines on \(dateFormatter.string(from: Date()))")
		}
		
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
		subcommands: [
			ConfigSet.self,
			ConfigShow.self,
			ConfigReset.self,
			ConfigOpen.self,
		]
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
	
	@Option(name: .long, help: "Locale used for summary date.")
	var locale: String?
	
	@Option(name: .long, help: "Should summary print date recap.")
	var summaryDate: Bool?

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
		
		if let locale = locale {
			WhatDidIDoConfig.shared.locale = Locale(identifier: locale)
			print("✔ Locale set to: \(locale)")
		}
		
		if let summaryDate = summaryDate {
			WhatDidIDoConfig.shared.summaryDate = summaryDate
			print("✔ Summary Date set to: \(summaryDate)")
		}

		if path == nil,
		   color == nil,
		   updateWarn == nil,
		   locale == nil,
		   summaryDate == nil {
			print("Nothing to set. Use --path, --color, --updateWarn, --locale, or --summaryDate")
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
		print("locale: \(cfg.locale)")
		print("summaryDate: \(cfg.summaryDate)")
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
		WhatDidIDoConfig.shared.locale = Locale.current
		WhatDidIDoConfig.shared.summaryDate = true
		WhatDidIDoConfigCore().save()
		print("✔ Configuration reset to defaults.")
	}
}

struct ConfigOpen: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "open-config",
		abstract: "Open the config file's folder"
	)
	
	func run() throws {
		try Helper.openConfigFolder(at: WhatDidIDoConfigCore().configURL)
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
		let locale = WhatDidIDoConfig.shared.locale

		print("shell: \(shell.toString())")
		print("os: \(os.toString())")
		print("history: \(historyURL.path)")
		print("color: \(WhatDidIDoConfig.shared.shouldColor)")
		print("locale: \(locale)")
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

	func run() throws {
		if #available(macOS 12.0, *) {
			let sema = DispatchSemaphore(value: 0)
			
			Task {
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
					print("Error while checking for update")
				}
				
				sema.signal()
			}
			
			let result = sema.wait(timeout: .now() + Double(WhatDidIDoConfig.shared.checkUpdateTimeout))
			
			if result == .timedOut {
				print(TerminalColor.applyColor(
					color: .red,
					to: "check-update timed out after \(WhatDidIDoConfig.shared.checkUpdateTimeout) seconds"
				))
			}
		} else {
			print(TerminalColor.applyColor(color: .red, to: "check-update is only available on macOS 12.0 or newer!"))
		}
	}
}

// MARK: - Completion

struct Completion: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Generate command completions."
	)
	
	@Argument(help: "The shell to generate completions for (zsh, bash, fish).")
	var shell: String
	
	func run() throws {
		let script: String
		
		switch shell.lowercased() {
		case "zsh":
			script = WhatDidIDo.completionScript(for: .zsh)
		case "bash":
			script = WhatDidIDo.completionScript(for: .bash)
		case "fish":
			script = WhatDidIDo.completionScript(for: .fish)
		default:
			print("Not a valid shell: \(shell)".withColor(.red))
			return
		}
		
		print(script)
	}
}

// MARK: - AI Features

struct AISummary: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ai-summary",
		abstract: "Create an AI summary of your command summary."
	)
	
	@OptionGroup var shellOpts: ShellOptions
	
	@Option(name: .shortAndLong, help: "How many recent commands to include for summary")
	var last: Int = 50
	
	func run() throws {
		#if os(macOS)
		
		if #available(macOS 26.0, *) {
			let sema = DispatchSemaphore(value: 0)
			
			Task {
				let history = try loadHistory(options: shellOpts)
				let lines = HistoryParser(history: history).summary(last: last)
				
				let core = SummarizedSummaryCore()
				
				let result = await core.generate(for: lines)
				
				print("Result")
				
				sema.signal()
			}
			
			sema.wait()
		} else {
			print("AI summarization is only available on macOS 26.0 or newer")
		}
		
		#else
		
		print("AI summarization is only available on macOS.")
		
		#endif
	}
}
