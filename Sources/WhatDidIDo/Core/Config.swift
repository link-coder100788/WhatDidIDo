import Foundation

// MARK: - WhatDidIDoConfig

/// Runtime configuration for the `whatdidido` tool.
///
/// Values are loaded from disk at startup via ``WhatDidIDoConfigCore/load()`` and written
/// back with ``WhatDidIDoConfigCore/save()``. Any property may be mutated in-process before
/// saving; unsaved changes are not persisted across invocations.
struct WhatDidIDoConfig {
	/// The shared, process-wide configuration instance.
	///
	/// - Note: Marked `nonisolated(unsafe)` because it is accessed from multiple async
	///   contexts without a lock; callers must ensure mutations happen before concurrent
	///   reads begin (which is guaranteed by the single-threaded CLI startup sequence).
	nonisolated(unsafe) static var shared = WhatDidIDoConfig()

	/// A custom path to the history file, overriding the shell's default location.
	///
	/// `nil` means "use the shell's default path" (see ``Shell/getDefaultDirectory(in:)``).
	var customPath: URL? = nil

	/// Whether ANSI colour codes should be included in output. Defaults to `true`.
	var shouldColor: Bool = true

	/// Whether a one-line update reminder should be printed when a newer release is available.
	/// Defaults to `true`.
	var updateAvailableWarning: Bool = true

	/// The last time an update check was performed, used to throttle checks to once per day.
	/// `nil` means a check has never been run.
	var lastUpdateCheck: Date? = nil

	/// Maximum number of seconds to wait for a `check-update` network request before timing out.
	/// Defaults to `15`.
	var checkUpdateTimeout: Int = 15

	/// The locale used to format dates in the `summary` command header. Defaults to
	/// ``Locale/current``.
	var locale: Locale = Locale.current

	/// Whether the `summary` command should print a date header. Defaults to `true`.
	var summaryDate: Bool = true
}

// MARK: - WhatDidIDoConfigCodable

/// A `Codable` mirror of ``WhatDidIDoConfig`` used for plist serialisation.
///
/// Keeping serialisation concerns separate from the runtime struct avoids adding
/// `Codable` conformance (and its associated stored-property requirements) directly
/// to ``WhatDidIDoConfig``.
struct WhatDidIDoConfigCodable: Encodable, Decodable {
	var customPath: URL?
	var shouldColor: Bool
	var updateAvailableWarning: Bool
	var lastUpdateCheck: Date?
	var checkUpdateTimeout: Int
	var locale: Locale
	var summaryDate: Bool

	/// Creates a ``WhatDidIDoConfigCodable`` that mirrors the values of `config`.
	///
	/// - Parameter config: The runtime config to copy values from.
	/// - Returns: A codable snapshot of `config`.
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

// MARK: - WhatDidIDoConfigCore

/// Handles reading from and writing to the on-disk configuration file.
///
/// The config file lives at `~/.whatdidido/config.plist` and is encoded as an Apple
/// property list. The directory is created automatically on first save.
struct WhatDidIDoConfigCore {
	/// The URL of the configuration plist file.
	var configURL: URL {
		FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido/config.plist")
	}

	/// Creates `~/.whatdidido/` if it does not already exist.
	///
	/// Failures are silently ignored — if the directory cannot be created, the subsequent
	/// write will also fail and surface the error there instead.
	private func ensureConfigDirectoryExists() {
		let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".whatdidido")
		try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
	}

	/// Encodes the current ``WhatDidIDoConfig/shared`` state and writes it to disk as a plist.
	///
	/// Encoding or write failures are silently ignored. Callers should not rely on this method
	/// throwing — check ``WhatDidIDoConfig/shared`` directly if validation is needed before saving.
	func save() {
		ensureConfigDirectoryExists()
		let plistEncoder = PropertyListEncoder()
		let toEncode = WhatDidIDoConfigCodable.from(config: WhatDidIDoConfig.shared)
		guard let encoded = try? plistEncoder.encode(toEncode) else { return }
		try? encoded.write(to: configURL)
	}

	/// Reads the on-disk plist and updates ``WhatDidIDoConfig/shared`` with the stored values.
	///
	/// If the file does not exist or cannot be decoded, this method returns without
	/// modifying the shared config, leaving all defaults in place.
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

/// A short alias for ``WhatDidIDoConfig``, useful in terse call-sites.
typealias CFG = WhatDidIDoConfig
