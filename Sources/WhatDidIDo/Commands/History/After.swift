import Foundation
import ArgumentParser

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
