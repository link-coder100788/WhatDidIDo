import Foundation

struct WhatDidIDoConfig {
	nonisolated(unsafe) static var shared = WhatDidIDoConfig()

	var customPath: URL? = nil
	var shouldColor: Bool = true
	var updateAvailableWarning: Bool = true
	var lastUpdateCheck: Date? = nil
	var checkUpdateTimeout: Int = 15
	var locale: Locale = Locale.current
	var summaryDate: Bool = true
}

struct WhatDidIDoConfigCodable: Encodable, Decodable {
	var customPath: URL?
	var shouldColor: Bool
	var updateAvailableWarning: Bool
	var lastUpdateCheck: Date?
	var checkUpdateTimeout: Int
	var locale: Locale
	var summaryDate: Bool

	static func from(config: WhatDidIDoConfig) -> WhatDidIDoConfigCodable {
		return WhatDidIDoConfigCodable(
			customPath: config.customPath,
			shouldColor: config.shouldColor,
			updateAvailableWarning: config.updateAvailableWarning,
			lastUpdateCheck: config.lastUpdateCheck,
			checkUpdateTimeout: config.checkUpdateTimeout,
			locale: config.locale,
			summaryDate: config.summaryDate,
		)
	}
}

struct WhatDidIDoConfigCore {
	var configURL: URL {
		FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido/config.plist")
	}

	private func ensureConfigDirectoryExists() {
		let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido")
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
	}

	func save() {
		ensureConfigDirectoryExists()
		let plistEncoder = PropertyListEncoder()
		let toEncode = WhatDidIDoConfigCodable.from(config: WhatDidIDoConfig.shared)
		guard let encoded = try? plistEncoder.encode(toEncode) else { return }
		try? encoded.write(to: configURL)
	}

	func load() {
		guard let encoded = try? Data(contentsOf: configURL) else { return }
		let plistDecoder = PropertyListDecoder()
		guard let decoded = try? plistDecoder.decode(WhatDidIDoConfigCodable.self, from: encoded) else { return }

		WhatDidIDoConfig.shared.customPath = decoded.customPath
		WhatDidIDoConfig.shared.shouldColor = decoded.shouldColor
		WhatDidIDoConfig.shared.updateAvailableWarning = decoded.updateAvailableWarning
		WhatDidIDoConfig.shared.lastUpdateCheck = decoded.lastUpdateCheck
		WhatDidIDoConfig.shared.checkUpdateTimeout = decoded.checkUpdateTimeout
		WhatDidIDoConfig.shared.locale = decoded.locale
		WhatDidIDoConfig.shared.summaryDate = decoded.summaryDate
	}
}

typealias CFG = WhatDidIDoConfig
