import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

struct UpdateResult {
	let currentVersion: String
	let latestVersion: String
	let updateAvailable: Bool
}

enum VersionError: Error, CustomStringConvertible {
	case networkError(statusCode: Int)
	case parseError
	case invalidVersion(String)
	case noNetwork
	case timedOut

	var description: String {
		switch self {
		case .networkError(let code): return "Network request failed with status code \(code)"
		case .parseError: return "Failed to parse GitHub API response"
		case .invalidVersion(let v): return "Invalid version string: \(v)"
		case .noNetwork: return "No network connection. Please check your internet and try again."
		case .timedOut: return "Request timed out. Please try again."
		}
	}
}

// MARK: - Version Logic

struct VersionChecker {
	static func isNewerVersion(_ latest: String, than current: String) -> Bool {
		let clean = { (v: String) in
			v.trimmingCharacters(in: .init(charactersIn: "v"))
			 .split(separator: ".").compactMap { Int($0) }
		}
		let latestParts = clean(latest)
		let currentParts = clean(current)
		let maxLength = max(latestParts.count, currentParts.count)
		let lPadded = latestParts + Array(repeating: 0, count: maxLength - latestParts.count)
		let cPadded = currentParts + Array(repeating: 0, count: maxLength - currentParts.count)

		for (l, c) in zip(lPadded, cPadded) {
			if l > c { return true }
			if l < c { return false }
		}
		return false
	}

	@available(macOS 12.0, *)
	static func fetchLatestVersion(owner: String, repo: String, token: String? = nil) async throws -> String {
		let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest")!
		var request = URLRequest(url: url)
		request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
		request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")
		if let token {
			request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
		}

		let data: Data
		let response: URLResponse
		
		do {
			(data, response) = try await URLSession.shared.data(for: request)
		} catch let urlError as URLError {
			switch urlError.code {
			case .notConnectedToInternet: throw VersionError.noNetwork
			case .timedOut: throw VersionError.timedOut
			default: throw VersionError.networkError(statusCode: -1)
			}
		}

		guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
			let code = (response as? HTTPURLResponse)?.statusCode ?? -1
			throw VersionError.networkError(statusCode: code)
		}
		
		guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
			  let tag = json["tag_name"] as? String else {
			throw VersionError.parseError
		}
		
		return tag
	}

	@available(macOS 12.0, *)
	static func checkForUpdate(owner: String, repo: String, currentVersion: String, token: String? = nil) async throws -> UpdateResult {
		let latest = try await fetchLatestVersion(owner: owner, repo: repo, token: token)
		return UpdateResult(
			currentVersion: currentVersion,
			latestVersion: latest,
			updateAvailable: isNewerVersion(latest, than: currentVersion)
		)
	}
}

