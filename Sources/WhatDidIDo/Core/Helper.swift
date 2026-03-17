import Foundation

struct Helper {
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
}

