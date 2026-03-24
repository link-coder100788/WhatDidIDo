import Foundation

// MARK: - HistoryFormatter

/// Applies consistent formatting to arrays of plain command strings.
///
/// `HistoryFormatter` is the building block for custom command output. The built-in
/// ``HistoryParser`` methods use it internally; you can use it directly when extending
/// `whatdidido` with your own commands.
///
/// ### Color
/// Color is entirely opt-in. Pass a ``TerminalColor/Color`` value to the relevant
/// mode to enable ANSI codes, or pass `nil` for plain output.
///
/// > Warning: It is the caller's responsibility to respect ``WhatDidIDoConfig/shouldColor``.
/// > Check `WhatDidIDoConfig.shared.shouldColor` before passing a color value, otherwise
/// > your output may contain raw escape codes when the user has disabled color.
///
/// ### Usage
/// ```swift
/// let formatter = HistoryFormatter()
/// let numbered = formatter.format(lines, mode: .numbered())
/// let prefixed = formatter.format(lines, mode: .prefixed(symbol: "▸", color: .blue))
/// ```
struct HistoryFormatter {

	// MARK: - Mode

	/// The formatting style to apply to each line.
	enum Mode {
		/// Prepends a right-aligned 1-based line number to each line.
		///
		/// - Parameters:
		///   - offset: Added to each line's index, allowing numbers to reflect position
		///     in the original history rather than the slice. Defaults to `0`.
		///   - color: The ANSI color to apply to the number. `nil` means no color.
		case numbered(offset: Int = 0, color: TerminalColor.Color? = nil)

		/// Prepends a symbol string to each line.
		///
		/// - Parameters:
		///   - symbol: The prefix to prepend (e.g. `"▸"`, `"cd"`).
		///   - color: The ANSI color to apply to the symbol. `nil` means no color.
		case prefixed(symbol: String, color: TerminalColor.Color? = nil)

		/// Returns lines unchanged.
		case plain
	}

	// MARK: - format

	/// Formats `lines` according to `mode` and returns the result.
	///
	/// - Parameters:
	///   - lines: The plain command strings to format.
	///   - mode: The ``Mode`` that controls how each line is decorated.
	/// - Returns: The formatted strings in the same order as `lines`.
	func format(_ lines: [String], mode: Mode) -> [String] {
		switch mode {
		case .numbered(let offset, let color):
			return lines.enumerated().map { i, line in
				let number = String(format: "%4d", i + 1 + offset)
				let coloredNumber = color.map {
					TerminalColor.applyColor(color: $0, to: number)
				} ?? number
				return "\(coloredNumber)  \(line)"
			}

		case .prefixed(let symbol, let color):
			return lines.map { line in
				let coloredSymbol = color.map {
					TerminalColor.applyColor(color: $0, to: symbol)
				} ?? symbol
				return "\(coloredSymbol) \(line)"
			}

		case .plain:
			return lines
		}
	}
}

// MARK: - BarEntry

/// A single entry in a bar-chart frequency table.
///
/// Produced by ``HistoryParser/mostUsed(top:)`` and consumed by ``HistoryBarFormatter``.
/// You can also construct entries manually when building custom frequency views.
struct BarEntry {
	/// The 1-based rank of this entry (1 = most used).
	let rank: Int

	/// The base command name (e.g. `"git"`, `"docker"`).
	let command: String

	/// The number of times this command appears in history.
	let count: Int

	/// The count of the most frequent entry in the set, used to normalise bar width.
	let max: Int
}

// MARK: - HistoryBarFormatter

/// Renders a slice of ``BarEntry`` values as a proportional ASCII bar chart.
///
/// Bar width, bar character, and bar color are all configurable. The formatter is
/// stateless beyond its settings, so one instance can be reused across multiple
/// `format` calls.
///
/// ### Usage
/// ```swift
/// var formatter = HistoryBarFormatter()
/// formatter.barWidth = 30
/// formatter.barCharacter = "█"
/// formatter.barColor = .green
/// let lines = formatter.format(entries)
/// ```
///
/// > Warning: It is the caller's responsibility to respect ``WhatDidIDoConfig/shouldColor``.
/// > Check `WhatDidIDoConfig.shared.shouldColor` before setting ``barColor``, otherwise
/// > your output may contain raw escape codes when the user has disabled color.
struct HistoryBarFormatter {

	/// The maximum number of characters a full-width bar can occupy.
	///
	/// Bars are scaled proportionally so the entry with the highest count always
	/// fills exactly this width. Defaults to `20`.
	var barWidth: Int = 20

	/// The character used to draw each bar. Defaults to `"▪"`.
	var barCharacter: Character = "▪"

	/// The ANSI color applied to the bar. `nil` means no color. Defaults to `nil`.
	var barColor: TerminalColor.Color? = nil

	/// Renders `entries` as formatted bar-chart lines.
	///
	/// Each line is formatted as `" <rank>  <bar>  <command> (<count>x)"`.
	/// Rank is right-aligned in a 2-character field. Bar width is proportional
	/// to `entry.count / entry.max`, with a minimum width of 1.
	///
	/// - Parameter entries: The ``BarEntry`` values to render, typically sorted
	///   by descending count.
	/// - Returns: One formatted string per entry.
	func format(_ entries: [BarEntry]) -> [String] {
		return entries.map { entry in
			let width = max(1, entry.count * barWidth / max(entry.max, 1))
			let bar = String(repeating: barCharacter, count: width)
			let coloredBar = barColor.map {
				TerminalColor.applyColor(color: $0, to: bar)
			} ?? bar
			let rank = String(format: "%2d", entry.rank)
			return "\(rank)  \(coloredBar)  \(entry.command) (\(entry.count)x)"
		}
	}
}
