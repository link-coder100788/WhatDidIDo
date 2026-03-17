import Foundation
import ArgumentParser

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
