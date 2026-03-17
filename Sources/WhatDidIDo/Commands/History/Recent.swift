import Foundation
import ArgumentParser

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
