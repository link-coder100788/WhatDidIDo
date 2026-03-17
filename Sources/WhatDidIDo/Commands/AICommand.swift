import Foundation
import ArgumentParser

struct AICommand: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "ai",
		abstract: "All of the ai features (macos only)",
		subcommands: [
			AISummary.self,
			AIRecent.self,
		]
	)
}

struct AISummary: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "summary",
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
				
				print(result ?? "Error")
				
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

struct AIRecent: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "recent",
		abstract: "Create an AI summary of your recent commands."
	)
	
	@OptionGroup var shellOpts: ShellOptions
	
	@Option(name: .shortAndLong, help: "How many recent commands to include for summary")
	var count: Int = 20
	
	func run() throws {
	#if os(macOS)

	if #available(macOS 26.0, *) {
		let sema = DispatchSemaphore(value: 0)
		
		Task {
			let history = try loadHistory(options: shellOpts)
			let lines = HistoryParser(history: history).recent(count)
			
			let core = SummarizedHistoryCore()
			
			let result = await core.generate(for: lines)
			
			print(result ?? "Error")
			
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

