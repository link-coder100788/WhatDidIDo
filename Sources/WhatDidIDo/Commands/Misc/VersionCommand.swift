import Foundation
import ArgumentParser

struct Version: ParsableCommand {
	static let configuration = CommandConfiguration(
		abstract: "Print the current version."
	)

	func run() {
		print("whatdidido \(Info.currentVersion)")
	}
}

struct CheckUpdate: ParsableCommand {
	static let configuration = CommandConfiguration(
		commandName: "check-update",
		abstract: "Check if a newer version is available on GitHub."
	)

	func run() throws {
		if #available(macOS 12.0, *) {
			let sema = DispatchSemaphore(value: 0)
			
			Task {
				do {
					let result = try await VersionChecker.checkForUpdate(
						owner: Info.owner,
						repo: Info.repo,
						currentVersion: Info.currentVersion
					)
					
					if result.updateAvailable {
						print("Update available: \(result.latestVersion) (you have \(result.currentVersion))")
					} else {
						print("Up to date: \(result.currentVersion)")
					}
				} catch {
					print("Error while checking for update")
				}
				
				sema.signal()
			}
			
			let result = sema.wait(timeout: .now() + Double(WhatDidIDoConfig.shared.checkUpdateTimeout))
			
			if result == .timedOut {
				print(TerminalColor.applyColor(
					color: .red,
					to: "check-update timed out after \(WhatDidIDoConfig.shared.checkUpdateTimeout) seconds"
				))
			}
		} else {
			print(TerminalColor.applyColor(color: .red, to: "check-update is only available on macOS 12.0 or newer!"))
		}
	}
}

