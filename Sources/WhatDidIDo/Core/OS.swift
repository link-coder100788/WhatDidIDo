// MARK: - OperatingSystem

/// The operating systems supported by `whatdidido`.
///
/// Used alongside ``Shell`` to resolve the correct default history file path
/// via ``Shell/getDefaultDirectory(in:)``.
enum OperatingSystem {
	/// Apple macOS.
	case macOS
	/// Any Linux distribution.
	case linux
	/// Microsoft Windows.
	case windows
}

extension OperatingSystem {
	/// A human-readable display name for this OS (e.g. `"MacOS"`, `"Linux"`).
	func toString() -> String {
		switch self {
		case .linux:   return "Linux"
		case .macOS:   return "MacOS"
		case .windows: return "Windows"
		}
	}
}
