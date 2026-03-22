import Foundation

#if os(macOS)
import FoundationModels

// MARK: - SummarizedSummaryCore

/// Generates a natural-language summary of a pre-processed command summary using
/// the on-device ``SystemLanguageModel``.
///
/// Available on macOS 26.0 and later only. The model runs entirely on-device —
/// no data is sent to external servers.
@available(macOS 26.0, *)
struct SummarizedSummaryCore {
	/// The system prompt that instructs the model how to interpret and format its response.
	static let systemPrompt = """
 You are a smart command-line assistant that summarizes developer terminal activity.
 Your job is to interpret summaries of shell commands and generate a concise, human-readable explanation.
 Focus on intent and patterns rather than individual commands.
 Keep your output short (2–4 sentences) and natural.
 If the input is unclear or minimal, indicate that concisely.
"""

	/// The default system language model used for generation.
	let model = SystemLanguageModel.default

	/// Generates a 2–4 sentence plain-English explanation of the provided summary lines.
	///
	/// The lines are joined with newlines and sent to the model as a single prompt.
	/// Returns `nil` and prints a diagnostic message if the model is unavailable or if
	/// generation fails.
	///
	/// - Parameter summary: The de-duplicated command summary produced by
	///   ``HistoryParser/summary(last:)``.
	/// - Returns: The model's response string, or `nil` on failure.
	func generate(for summary: [String]) async -> String? {
		guard model.isAvailable else {
			print("Not available: \(model.availability)")
			return nil
		}
		
		do {
			let prompt = summary.joined(separator: "\n")
			let session = LanguageModelSession(
				model: model,
				instructions: SummarizedSummaryCore.systemPrompt
			)
			
			let result = try await session.respond(to: prompt)
			return result.content
		} catch {
			print("Error: \(error)")
			return nil
		}
	}
}

// MARK: - SummarizedHistoryCore

/// Generates a natural-language summary of raw recent history lines using
/// the on-device ``SystemLanguageModel``.
///
/// Functionally identical to ``SummarizedSummaryCore`` but intended for use with
/// unfiltered history output (i.e. the result of ``HistoryParser/recent(_:)`` rather
/// than ``HistoryParser/summary(last:)``).
///
/// Available on macOS 26.0 and later only.
@available(macOS 26.0, *)
struct SummarizedHistoryCore {
	/// The system prompt that instructs the model how to interpret and format its response.
	static let systemPrompt = """
 You are a smart command-line assistant that summarizes developer terminal activity.
 Your job is to interpret summaries of shell commands and generate a concise, human-readable explanation.
 Focus on intent and patterns rather than individual commands.
 Keep your output short (2–4 sentences) and natural.
 If the input is unclear or minimal, indicate that concisely.
"""

	/// The default system language model used for generation.
	let model = SystemLanguageModel.default
	
	/// Generates a 2–4 sentence plain-English explanation of the provided history lines.
	///
	/// The lines are joined with newlines and sent to the model as a single prompt.
	/// Returns `nil` and prints a diagnostic message if the model is unavailable or if
	/// generation fails.
	///
	/// - Parameter history: The recent command lines produced by ``HistoryParser/recent(_:)``.
	/// - Returns: The model's response string, or `nil` on failure.
	func generate(for history: [String]) async -> String? {
		guard model.isAvailable else {
			print("Not available: \(model.availability)")
			return nil
		}
		
		do {
			let prompt = history.joined(separator: "\n")
			let session = LanguageModelSession(
				model: model,
				instructions: SummarizedHistoryCore.systemPrompt
			)
			
			let result = try await session.respond(to: prompt)
			return result.content
		} catch {
			print("Error: \(error)")
			return nil
		}
	}
}

#endif
