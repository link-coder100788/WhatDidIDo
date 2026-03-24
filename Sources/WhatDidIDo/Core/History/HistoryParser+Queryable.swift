import Foundation

extension HistoryParser {
	/// Returns the most recent `count` commands, filtered by a custom predicate.
	///
	/// Session-break commands (`clear`, `exit`, `reset`, `logout`) are always excluded
	/// before the predicate is applied. Unlike ``recent(_:)``, output is plain strings
	/// with no ANSI colour codes or line numbers.
	///
	/// - Parameters:
	///   - count: Maximum number of commands to consider. Defaults to `20`.
	///   - predicate: A closure that receives each command string and returns `true`
	///     to include it in the result.
	/// - Returns: The filtered command strings in chronological order.
	func recentFiltered(count: Int = 20, where predicate: (String) -> Bool) -> [String] {
		let sessionBreakers: Set<String> = ["clear", "exit", "reset", "logout"]
		let filtered = history.content.filter { !sessionBreakers.contains($0.lowercased()) }
		let slice = Array(filtered.suffix(count))

		var result = [String]()

		for line in slice {
			if predicate(line) {
				result.append(line)
			}
		}

		return result
	}

	/// Returns the top `count` most-used base commands, filtered by a custom predicate.
	///
	/// The predicate runs against the base command token (the first whitespace-delimited
	/// word, e.g. `"git"`, `"cd"`, `"ls"`) before frequency is tallied, so excluded
	/// commands don't affect the ranking of the remaining ones. Unlike ``mostUsed(top:)``,
	/// output is plain strings with no ANSI colour codes or bar chart formatting.
	///
	/// - Parameters:
	///   - count: How many top commands to return. Defaults to `10`.
	///   - predicate: A closure that receives the base command token and returns `true`
	///     to include it in the frequency count.
	/// - Returns: Ranked strings in the format `"<rank>  <command> (<n>x)"`.
	func topFiltered(count: Int = 10, where predicate: (String) -> Bool) -> [String] {
		var freq: [String: Int] = [:]

		for cmd in history.content {
			let base = cmd.components(separatedBy: .whitespaces).first ?? cmd
			if predicate(base) {
				freq[base, default: 0] += 1
			}
		}

		let sorted = freq.sorted { $0.value > $1.value }.prefix(count)

		var result = [String]()

		for (i, pair) in sorted.enumerated() {
			result.append("\(String(format: "%2d", i + 1))  \(pair.key) (\(pair.value)x)")
		}

		return result
	}

	/// Searches history for `query` and formats each match using a custom transform.
	///
	/// Every line that contains `query` (case-insensitive) is passed to `transform`
	/// along with its 1-based line number. Unlike ``search(_:)``, no highlighting or
	/// ANSI colour codes are applied — formatting is entirely up to the caller.
	///
	/// - Parameters:
	///   - query: The search term to look for (case-insensitive substring match).
	///   - transform: A closure that receives the 1-based line number and the raw
	///     matching command string, and returns a formatted output string.
	/// - Returns: The transformed strings for every matching line, in order.
	func searchTransformed(query: String, transform: (Int, String) -> String) -> [String] {
		var result = [String]()

		for (i, line) in history.content.enumerated() {
			if line.localizedCaseInsensitiveContains(query) {
				result.append(transform(i + 1, line))
			}
		}

		return result
	}

	/// Returns a de-duplicated digest of the last `last` commands, filtered by a custom predicate.
	///
	/// Deduplication runs first (keyed on the base command token), then the predicate
	/// is applied to the deduplicated result. Unlike ``summary(last:)``, output is plain
	/// strings with no ANSI colour codes or `▸` prefix.
	///
	/// - Parameters:
	///   - last: How many recent history entries to consider. Defaults to `50`.
	///   - predicate: A closure that receives each deduplicated command string and returns
	///     `true` to include it in the result.
	/// - Returns: The filtered, deduplicated command strings in chronological order.
	func summaryFiltered(last: Int = 50, where predicate: (String) -> Bool) -> [String] {
		var seen = Set<String>()
		let unique = history.content.suffix(last).filter { line in
			let base = line.components(separatedBy: .whitespaces).first ?? line
			return seen.insert(base).inserted
		}

		var result = [String]()

		for line in unique {
			if predicate(line) {
				result.append(line)
			}
		}

		return result
	}

	/// Applies a transform to every line in `lines`, returning the mapped results.
	///
	/// Intended as a post-processing step after any ``HistoryParser`` method — for
	/// example, stripping ANSI codes, adding a custom prefix, or reformatting line numbers.
	///
	/// - Parameters:
	///   - lines: Any array of strings, typically the output of another parser method.
	///   - transform: A closure that receives a single line and returns the transformed string.
	/// - Returns: The transformed strings in the same order as `lines`.
	func map(over lines: [String], transform: (String) -> String) -> [String] {
		var result = [String]()

		for line in lines {
			result.append(transform(line))
		}

		return result
	}

	/// Reduces `lines` into a single value using a custom accumulator.
	///
	/// Mirrors Swift's `reduce(into:_:)` but scoped to parser output, making it easy
	/// to build aggregations the built-in methods don't cover — frequency maps,
	/// custom counts, collected sets, and so on.
	///
	/// - Parameters:
	///   - lines: Any array of strings, typically the output of another parser method.
	///   - initial: The initial value of the accumulator.
	///   - accumulate: A closure that takes the current accumulator value (as `inout`)
	///     and a single line, and mutates the accumulator in place.
	/// - Returns: The final accumulated value after all lines have been processed.
	func reduce<T>(over lines: [String], into initial: T, _ accumulate: (inout T, String) -> Void) -> T {
		var result = initial

		for line in lines {
			accumulate(&result, line)
		}

		return result
	}

	/// Evaluates custom logic against the raw history, returning the result as formatted strings.
	///
	/// Use this as an escape hatch when the built-in methods don't cover your use case.
	///
	/// - Parameter predicate: A closure that receives the raw ``History`` and returns
	///   an array of formatted output strings.
	/// - Returns: Whatever the closure returns.
	func query(where predicate: (History) -> [String]) -> [String] {
		predicate(history)
	}
}
