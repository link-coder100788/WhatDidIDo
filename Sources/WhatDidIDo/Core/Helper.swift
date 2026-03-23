import Foundation

/// Miscellaneous utility functions used across command implementations.
struct Helper {
	/// Silently checks for a newer release in the background and prints a one-line reminder
	/// if one is available.
	///
	/// The check is skipped entirely when:
	/// - ``WhatDidIDoConfig/updateAvailableWarning`` is `false`.
	/// - A check was already performed within the last 24 hours
	///   (``WhatDidIDoConfig/lastUpdateCheck`` is set and recent).
	///
	/// On success the ``WhatDidIDoConfig/lastUpdateCheck`` timestamp is updated and the
	/// config is saved to disk. Network or parsing errors are swallowed silently so that
	/// a failed check never interrupts normal command output.
	///
	/// - Note: Requires macOS 12.0 or later for `async/await` URLSession support.
	///   On older systems the call is a no-op.
	static func embeddedUpdateCheck() async {
		guard WhatDidIDoConfig.shared.updateAvailableWarning else { return }

		let checkInterval: TimeInterval = 60 * 60 * 24
		 
		if let last = WhatDidIDoConfig.shared.lastUpdateCheck,
		   Date().timeIntervalSince(last) < checkInterval {
			return
		}

		if #available(macOS 12.0, *) {
			do {
				let result = try await VersionChecker.checkForUpdate(
				 owner: Info.owner,
				 repo: Info.repo,
				 currentVersion: Info.currentVersion
				)
			 
				if result.updateAvailable {
					print("Update available: \(result.latestVersion) (you have \(result.currentVersion))")
					print("Disable these warnings with: whatdidido config --set updateWarn false")
				}
			 
				WhatDidIDoConfig.shared.lastUpdateCheck = Date()
				WhatDidIDoConfigCore().save()
				} catch { }
		 }
	}

	/// Opens the folder containing the `whatdidido` config file in the system file manager.
	///
	/// The platform-appropriate command is used:
	/// - **macOS**: `/usr/bin/open <folder>`
	/// - **Linux**: `/usr/bin/xdg-open <folder>` (requires `xdg-utils` to be installed)
	/// - **Windows**: `cmd /c start "" <folder>`
	///
	/// - Parameter url: The URL of the config *file* whose parent directory should be opened.
	/// - Throws: Any error thrown by `Process/run()` if the helper binary cannot be launched.
	static func openConfigFolder(at url: URL) throws {
		let folderPath = url.deletingLastPathComponent().path
		
		let ps = Process()
		
		#if os(macOS)
		ps.executableURL = URL(fileURLWithPath: "/usr/bin/open")
		ps.arguments = [folderPath]
		#elseif os(Linux)
		// We try xdg-open
		ps.executableURL = URL(fileURLWithPath: "/usr/bin/xdg-open")
		ps.arguments = [folderPath]
		#elseif os(Windows)
		ps.executableURL = URL(fileURLWithPath: "cmd")
		ps.arguments = ["/c", "start", "", folderPath]
		#endif
		
		try ps.run()
	}
	
	static func saveAndCreateMetadata() {
		if !ProgramMetadata.exists() {
			ProgramMetadata.save(ProgramMetadata.shared)
		} else {
			
		}
	}
}
