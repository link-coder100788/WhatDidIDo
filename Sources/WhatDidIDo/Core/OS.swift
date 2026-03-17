enum OperatingSystem {
	case macOS
	case linux
	case windows
}

extension OperatingSystem {
	func toString() -> String {
		switch self {
		case .linux: return "Linux"
		case .macOS: return "MacOS"
		case .windows: return "Windows"
		}
	}
}
