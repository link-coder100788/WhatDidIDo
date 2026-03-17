import Foundation
import ArgumentParser

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
