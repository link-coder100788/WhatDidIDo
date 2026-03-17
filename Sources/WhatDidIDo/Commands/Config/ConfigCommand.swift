import Foundation
import ArgumentParser

struct Config: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "View or update your whatdidido configuration.",
		subcommands: [
			ConfigSet.self,
			ConfigShow.self,
			ConfigReset.self,
			ConfigOpen.self,
		]
	)
}

struct ConfigSet: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "set",
		abstract: "Set a config value."
	)

	@Option(name: .long, help: "Custom path to your history file.")
	var path: String?

	@Option(name: .long, help: "Enable or disable color output (true/false).")
	var color: Bool?
	
	@Option(name: .long, help: "Enable warnings regarding if there is an available update.")
	var updateWarn: Bool?
	
	@Option(name: .long, help: "Locale used for summary date.")
	var locale: String?
	
	@Option(name: .long, help: "Should summary print date recap.")
	var summaryDate: Bool?

	func run() throws {
		WhatDidIDoConfigCore().load()

		if let path = path {
			WhatDidIDoConfig.shared.customPath = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
			print("✔ Custom history path set to: \(path)")
		}

		if let color = color {
			WhatDidIDoConfig.shared.shouldColor = color
			print("✔ Color output set to: \(color)")
		}
		
		if let updateWarn = updateWarn {
			WhatDidIDoConfig.shared.updateAvailableWarning = updateWarn
			print("✔ Update warning set to: \(updateWarn)")
		}
		
		if let locale = locale {
			WhatDidIDoConfig.shared.locale = Locale(identifier: locale)
			print("✔ Locale set to: \(locale)")
		}
		
		if let summaryDate = summaryDate {
			WhatDidIDoConfig.shared.summaryDate = summaryDate
			print("✔ Summary Date set to: \(summaryDate)")
		}

		if path == nil,
		   color == nil,
		   updateWarn == nil,
		   locale == nil,
		   summaryDate == nil {
			print("Nothing to set. Use --path, --color, --updateWarn, --locale, or --summaryDate")
			return
		}

		WhatDidIDoConfigCore().save()
	}
}

struct ConfigShow: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "show",
		abstract: "Print your current configuration."
	)

	func run() {
		WhatDidIDoConfigCore().load()
		let cfg = WhatDidIDoConfig.shared
		print("color: \(cfg.shouldColor)")
		print("path: \(cfg.customPath?.path ?? "(default — auto-detected from shell)")")
		print("updateReminders: \(cfg.updateAvailableWarning)")
		print("locale: \(cfg.locale)")
		print("summaryDate: \(cfg.summaryDate)")
	}
}

struct ConfigReset: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "reset",
		abstract: "Reset configuration to defaults."
	)

	func run() throws {
		WhatDidIDoConfig.shared.customPath = nil
		WhatDidIDoConfig.shared.shouldColor = true
		WhatDidIDoConfig.shared.locale = Locale.current
		WhatDidIDoConfig.shared.summaryDate = true
		WhatDidIDoConfigCore().save()
		print("✔ Configuration reset to defaults.")
	}
}

struct ConfigOpen: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "open-config",
		abstract: "Open the config file's folder"
	)
	
	func run() throws {
		try Helper.openConfigFolder(at: WhatDidIDoConfigCore().configURL)
	}
}

