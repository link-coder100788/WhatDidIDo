import Foundation
import ArgumentParser

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
