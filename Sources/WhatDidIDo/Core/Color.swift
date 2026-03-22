// MARK: - TerminalColor

/// Provides ANSI escape-code strings for terminal colour and text styling.
///
/// All colour properties respect ``WhatDidIDoConfig/shouldColor``: when colour output is
/// disabled, every property returns an empty string so the same interpolation code
/// works regardless of the current setting.
///
/// ### Usage
/// ```swift
/// let c = TerminalColor()
/// print("\(c.green)Success\(c.reset)")
///
/// // Or via the String extension helpers:
/// print("Success".withColor(.green))
/// ```
struct TerminalColor {
	/// Returns `code` when colour is enabled, or an empty string when it is disabled.
	private func color(_ code: String) -> String {
		return WhatDidIDoConfig.shared.shouldColor ? code : ""
	}

	/// ANSI red foreground (`\e[31m`).
	var red: String    { color("\u{001B}[31m") }
	/// ANSI green foreground (`\e[32m`).
	var green: String  { color("\u{001B}[32m") }
	/// ANSI cyan foreground (`\e[36m`).
	var cyan: String   { color("\u{001B}[36m") }
	/// ANSI yellow foreground (`\e[33m`).
	var yellow: String { color("\u{001B}[33m") }
	/// ANSI blue foreground (`\e[34m`).
	var blue: String   { color("\u{001B}[34m") }
	/// ANSI bold / bright attribute (`\e[1m`).
	var bold: String   { color("\u{001B}[1m") }
	/// ANSI dim / faint attribute (`\e[2m`).
	var dim: String    { color("\u{001B}[2m") }
	/// ANSI reset — clears all active colour and attribute codes (`\e[0m`).
	var reset: String  { color("\u{001B}[0m") }

	// MARK: - Color enum

	/// A type-safe enumeration of the colours and text attributes supported by ``TerminalColor``.
	enum Color {
		case red
		case green
		case cyan
		case yellow
		case blue
		case bold
		case dim
		case reset

		/// Returns the ANSI escape-code string for this colour/attribute.
		///
		/// Respects ``WhatDidIDoConfig/shouldColor`` via the ``TerminalColor`` instance it
		/// constructs internally.
		func getMarker() -> String {
			switch self {
			case .red:    return TerminalColor().red
			case .blue:   return TerminalColor().blue
			case .cyan:   return TerminalColor().cyan
			case .yellow: return TerminalColor().yellow
			case .green:  return TerminalColor().green
			case .bold:   return TerminalColor().bold
			case .dim:    return TerminalColor().dim
			case .reset:  return TerminalColor().reset
			}
		}
	}

	/// Wraps `text` with the ANSI codes for `color` and a trailing reset.
	///
	/// When colour output is disabled, `text` is returned unchanged.
	///
	/// - Parameters:
	///   - color: The colour or attribute to apply.
	///   - text: The string to colour.
	/// - Returns: `"\(colorCode)\(text)\(reset)"`, or just `text` when colour is off.
	static func applyColor(color: Color, to text: String) -> String {
		return "\(color.getMarker())\(text)\(TerminalColor().reset)"
	}
}

// MARK: - String helpers

extension String {
	/// Returns a copy of this string wrapped in the ANSI codes for `color`.
	///
	/// Shorthand for ``TerminalColor/applyColor(color:to:)``.
	///
	/// - Parameter color: The colour or attribute to apply.
	/// - Returns: The coloured string.
	func color(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}

	/// Returns a copy of this string wrapped in the ANSI codes for `color`.
	///
	/// Alias for ``color(_:)`` with a more readable call-site when chaining.
	///
	/// - Parameter color: The colour or attribute to apply.
	/// - Returns: The coloured string.
	func withColor(_ color: TerminalColor.Color) -> String {
		return TerminalColor.applyColor(color: color, to: self)
	}
}
