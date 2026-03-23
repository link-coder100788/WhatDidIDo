import Foundation

// MARK: - UsageRecord

/// A single recorded invocation of a `whatdidido` command.
struct UsageRecord: Codable {
	/// The subcommand name as it appears on the CLI (e.g. `"top"`, `"for"`, `"recent"`).
	let command: String

	/// The arguments and flags passed by the user, in the order they were received.
	///
	/// Callers should strip sensitive values (e.g. path arguments) before recording,
	/// or pass an empty array if argument tracking is not desired for that command.
	let args: [String]

	/// When the command was invoked.
	let timestamp: Date

	/// The number of output lines the command produced, or `nil` if the command
	/// does not produce countable line output (e.g. `check`, `version`).
	let resultCount: Int?
}

// MARK: - CommandAggregate

/// Accumulated statistics for a single command name across all recorded invocations.
struct CommandAggregate: Codable {
	/// Total number of times this command has been invoked.
	var invocationCount: Int

	/// The timestamp of the most recent invocation.
	var lastUsed: Date

	/// The timestamp of the first ever recorded invocation.
	var firstUsed: Date

	/// The sum of all non-nil `resultCount` values, used to compute the average.
	var totalResultCount: Int

	/// The number of invocations that had a non-nil `resultCount`,
	/// i.e. the denominator for `averageResultCount`.
	var resultCountSamples: Int

	/// The average number of output lines across all invocations that reported one,
	/// or `nil` if no result counts have been recorded for this command.
	var averageResultCount: Double? {
		guard resultCountSamples > 0 else { return nil }
		return Double(totalResultCount) / Double(resultCountSamples)
	}

	/// Creates an aggregate seeded from a single invocation record.
	init(from record: UsageRecord) {
		invocationCount    = 1
		lastUsed           = record.timestamp
		firstUsed          = record.timestamp
		totalResultCount   = record.resultCount ?? 0
		resultCountSamples = record.resultCount != nil ? 1 : 0
	}

	/// Folds a new invocation record into this aggregate, updating all running totals.
	mutating func update(with record: UsageRecord) {
		invocationCount += 1
		if record.timestamp > lastUsed  { lastUsed  = record.timestamp }
		if record.timestamp < firstUsed { firstUsed = record.timestamp }
		if let count = record.resultCount {
			totalResultCount   += count
			resultCountSamples += 1
		}
	}
}

// MARK: - UsageMetadata

/// The top-level structure written to `~/.whatdidido/usage.json`.
///
/// Combines the full invocation log with a pre-computed aggregate index so that
/// stats queries don't need to scan every record. Both are updated atomically on
/// each `append` call.
struct UsageMetadata: Codable {
	/// Schema version. Increment if the structure changes in a breaking way.
	var version: Int = 1

	/// All recorded invocations, oldest first.
	var records: [UsageRecord]

	/// Per-command aggregates, keyed by command name.
	///
	/// Always in sync with `records` — updated on every `append` call.
	var aggregates: [String: CommandAggregate]

	/// An empty metadata document.
	static var empty: UsageMetadata {
		UsageMetadata(version: 1, records: [], aggregates: [:])
	}

	/// The total number of invocations recorded across all commands.
	var totalInvocations: Int { records.count }

	/// Returns the `top` most-used commands ranked by invocation count, descending.
	func topCommands(limit: Int = 10) -> [(command: String, aggregate: CommandAggregate)] {
		aggregates
			.sorted { $0.value.invocationCount > $1.value.invocationCount }
			.prefix(limit)
			.map { (command: $0.key, aggregate: $0.value) }
	}

	/// Returns the most recently used command name, or `nil` if no records exist.
	var mostRecentCommand: String? {
		records.last?.command
	}
}

// MARK: - UsageMetadataCore

/// Handles reading from and writing to `~/.whatdidido/usage.json`.
///
/// All mutations go through `append(record:)`, which loads the current file,
/// folds in the new record, and writes the result back atomically using a
/// temporary file + rename to avoid partial writes.
struct UsageMetadataCore {
	/// The URL of the metadata JSON file.
	var metadataURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".whatdidido/usage.json")
	}

	private var directoryURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".whatdidido")
	}

	// MARK: Persistence

	/// Ensures `~/.whatdidido/` exists. Failures are silently ignored.
	private func ensureDirectoryExists() {
		try? FileManager.default.createDirectory(
			at: directoryURL,
			withIntermediateDirectories: true
		)
	}

	private var encoder: JSONEncoder {
		let e = JSONEncoder()
		e.outputFormatting    = [.prettyPrinted, .sortedKeys]
		e.dateEncodingStrategy = .iso8601
		return e
	}

	private var decoder: JSONDecoder {
		let d = JSONDecoder()
		d.dateDecodingStrategy = .iso8601
		return d
	}

	/// Loads and returns the current ``UsageMetadata`` from disk.
	///
	/// Returns ``UsageMetadata/empty`` if the file does not exist or cannot be decoded,
	/// so callers never need to handle a nil result.
	func load() -> UsageMetadata {
		guard
			let data     = try? Data(contentsOf: metadataURL),
			let metadata = try? decoder.decode(UsageMetadata.self, from: data)
		else {
			return .empty
		}
		return metadata
	}

	/// Writes `metadata` to disk atomically (temp file + rename).
	///
	/// - Throws: Any `FileManager` or encoding error encountered during the write.
	func save(_ metadata: UsageMetadata) throws {
		ensureDirectoryExists()
		let data    = try encoder.encode(metadata)
		let tempURL = directoryURL.appendingPathComponent("metadata.tmp.json")
		try data.write(to: tempURL, options: .atomic)
		_ = try FileManager.default.replaceItemAt(metadataURL, withItemAt: tempURL)
	}

	/// Appends `record` to the metadata file, updating the aggregate index in the same write.
	///
	/// This is the only mutation callers should use — it guarantees that `records`
	/// and `aggregates` are always consistent.
	///
	/// Failures are silently swallowed so a broken metadata file never interrupts
	/// normal command output.
	func append(record: UsageRecord) {
		var metadata = load()
		metadata.records.append(record)

		if metadata.aggregates[record.command] != nil {
			metadata.aggregates[record.command]!.update(with: record)
		} else {
			metadata.aggregates[record.command] = CommandAggregate(from: record)
		}

		try? save(metadata)
	}

	/// Deletes all recorded invocations and resets all aggregates.
	///
	/// The metadata file is replaced with an empty document rather than deleted,
	/// so the directory and file always exist after first use.
	func reset() throws {
		try save(.empty)
	}
}

// MARK: - UsageTracker

/// The public call-site API for recording a command invocation.
///
/// Every `whatdidido` command should call `UsageTracker.record(...)` at the end
/// of its `run()` method, after the result lines are known.
///
/// ```swift
/// func run() throws {
///     let history = try loadHistory(options: shellOpts)
///     let lines   = HistoryParser(history: history).recent(count)
///     printLines(lines)
///     UsageTracker.record(command: "recent", args: [], resultCount: lines.count)
/// }
/// ```
enum UsageTracker {
	private static let core = UsageMetadataCore()

	/// Records a single command invocation.
	///
	/// The call is non-blocking and failures are silently ignored, so it is safe
	/// to call from any command's `run()` method without affecting output or exit codes.
	///
	/// - Parameters:
	///   - command:     The subcommand name (e.g. `"top"`, `"recent"`, `"for"`).
	///   - args:        Arguments and flags passed by the user. Omit or pass `[]`
	///                  for commands where arguments are sensitive (e.g. `search`).
	///   - resultCount: Number of output lines produced, or `nil` for commands
	///                  that don't have countable output.
	static func record(command: String, args: [String] = [], resultCount: Int? = nil) {
		let record = UsageRecord(
			command:     command,
			args:        args,
			timestamp:   Date(),
			resultCount: resultCount
		)
		core.append(record: record)
	}
}

struct ProgramMetadata {
	nonisolated(unsafe) static var shared = ProgramMetadata.Contents(Info.currentVersion)
	
	private static var fileURL: URL {
		FileManager.default.homeDirectoryForCurrentUser
			.appendingPathComponent(".whatdidido/metadata.json")
	}
	
	struct Contents: Codable {
		var id: UUID
		var locale: Locale
		var buildDate: Date
		var buildVersion: String
		
		init(_ version: String) {
			id = UUID()
			locale = Locale.current
			buildDate = Date()
			buildVersion = version
		}
	}
	
	static func save(_ contents: Contents) {
		do {
			let encoder = JSONEncoder()
			encoder.outputFormatting = .prettyPrinted
			let encoded = try encoder.encode(contents)
			try encoded.write(to: ProgramMetadata.fileURL)
		} catch {
			
		}
	}
	
	static func load() -> Contents? {
		do {
			let decoder = JSONDecoder()
			let encoded = try Data(contentsOf: ProgramMetadata.fileURL)
			let decoded = try decoder.decode(Contents.self, from: encoded)
			return decoded
		} catch {
			return nil
		}
	}
	
	static func exists() -> Bool {
		if #available(macOS 13.0, *) {
			return FileManager.default.fileExists(atPath: fileURL.path()) ? true : false
		} else {
			print("Cant check becuase it dont work")
			return false
		}
	}
	
	static func updateShared(with new: Contents) {
		shared.id = new.id
		shared.locale = new.locale
		shared.buildDate = new.buildDate
		shared.buildVersion = new.buildVersion
	}
}
