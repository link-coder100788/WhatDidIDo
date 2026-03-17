import Foundation
import ArgumentParser

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
