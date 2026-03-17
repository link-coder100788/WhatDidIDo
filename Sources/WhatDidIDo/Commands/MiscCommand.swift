import Foundation
import ArgumentParser

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
