import Foundation

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - UpdateResult

/// The outcome of a version check against the GitHub Releases API.
struct UpdateResult {
	/// The version string of the locally installed binary (e.g. `"1.5.6"`).
	let currentVersion: String

	/// The tag name of the latest GitHub release (e.g. `"v1.6.0"`).
	let latestVersion: String

	/// `true` when ``latestVersion`` is semantically newer than ``currentVersion``.
	let updateAvailable: Bool
}

// MARK: - VersionError

/// Errors that can be thrown during a version-check network request.
enum VersionError: Error, CustomStringConvertible {
	/// The server returned a non-200 HTTP status code.
	case networkError(statusCode: Int)

	/// The GitHub API response could not be parsed as expected JSON.
	case parseError

	/// A version string contained non-numeric components and could not be compared.
	case invalidVersion(String)

	/// The device has no internet connection.
	case noNetwork

	/// The network request exceeded its time budget.
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

// MARK: - VersionChecker

/// Compares semantic version strings and queries the GitHub Releases API for the latest release.
struct VersionChecker {
	/// Returns `true` when `latest` is a higher semantic version than `current`.
	///
	/// Both strings are normalised by stripping a leading `"v"` and splitting on `"."`.
	/// Each numeric component is compared in order; missing trailing components are treated
	/// as `0` (so `"1.2"` == `"1.2.0"`).
	///
	/// - Parameters:
	///   - latest: The candidate version to test (e.g. `"v1.6.0"`).
	///   - current: The baseline version to compare against (e.g. `"1.5.6"`).
	/// - Returns: `true` if `latest` is strictly greater than `current`.
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

	/// Fetches the tag name of the latest release from GitHub for the given repository.
	///
	/// Uses the GitHub REST API endpoint `GET /repos/{owner}/{repo}/releases/latest`.
	/// An optional `token` can be supplied for private repositories or to avoid rate limiting.
	///
	/// - Parameters:
	///   - owner: The GitHub repository owner (username or organisation).
	///   - repo: The repository name.
	///   - token: An optional personal access token sent as a `Bearer` authorisation header.
	/// - Returns: The `tag_name` string from the latest release.
	/// - Throws: A ``VersionError`` describing the failure.
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

	/// Checks whether a newer release is available on GitHub and returns an ``UpdateResult``.
	///
	/// Convenience wrapper around ``fetchLatestVersion(owner:repo:token:)`` and
	/// ``isNewerVersion(_:than:)``.
	///
	/// - Parameters:
	///   - owner: The GitHub repository owner.
	///   - repo: The repository name.
	///   - currentVersion: The version string of the installed binary to compare against.
	///   - token: An optional personal access token.
	/// - Returns: An ``UpdateResult`` describing the comparison outcome.
	/// - Throws: A ``VersionError`` if the network request or parsing fails.
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
