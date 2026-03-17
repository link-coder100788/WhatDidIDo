import Foundation
import ArgumentParser

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
			let dateFormatter = DateFormatter()
			
			dateFormatter.locale = WhatDidIDoConfig.shared.locale
			dateFormatter.setLocalizedDateFormatFromTemplate("MMMMdYYYY")
		
			print("Summary of last \(last) lines on \(dateFormatter.string(from: Date()))")
		}
		
		printLines(lines)
	}
}
