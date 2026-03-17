struct TerminalColor {
	private func color(_ code: String) -> String {
		return WhatDidIDoConfig.shared.shouldColor ? code : ""
	}
	
	var red: String    { color("\u{001B}[31m") }
	var green: String  { color("\u{001B}[32m") }
	var cyan: String   { color("\u{001B}[36m") }
	var yellow: String { color("\u{001B}[33m") }
	var blue: String   { color("\u{001B}[34m") }
	var bold: String   { color("\u{001B}[1m") }
	var dim: String    { color("\u{001B}[2m") }
	var reset: String  { color("\u{001B}[0m") }
	
	enum Color {
		case red
		case green
		case cyan
		case yellow
		case blue
		case bold
		case dim
		case reset
		
		func getMarker() -> String {
			switch self {
			case .red:
				return TerminalColor().red
			case .blue:
				return TerminalColor().blue
			case .cyan:
				return TerminalColor().cyan
			case .yellow:
				return TerminalColor().yellow
			case .green:
				return TerminalColor().green
			case .bold:
				return TerminalColor().bold
			case .dim:
				return TerminalColor().dim
			case .reset:
				return TerminalColor().reset
			}
		}
	}
	
	static func applyColor(color: Color, to text: String) -> String {
		return "\(color.getMarker())\(text)\(TerminalColor().reset)"
	}
}

extension String {
	func color(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}
	
	func withColor(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}
}
