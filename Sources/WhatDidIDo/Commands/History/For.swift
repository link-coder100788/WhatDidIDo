import Foundation
import ArgumentParser

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
