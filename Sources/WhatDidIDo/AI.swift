import Foundation

#if os(macOS)
import FoundationModels

@available(macOS 26.0, *)
struct SummarizedSummaryCore {
	static let systemPrompt = """
 You are a smart command-line assistant that summarizes developer terminal activity.
 Your job is to interpret summaries of shell commands and generate a concise, human-readable explanation.
 Focus on intent and patterns rather than individual commands.
 Keep your output short (2–4 sentences) and natural.
 If the input is unclear or minimal, indicate that concisely.
"""

	let model = SystemLanguageModel.default

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

@available(macOS 26.0, *)
struct SummarizedHistoryCore {
	static let systemPrompt = """
 You are a smart command-line assistant that summarizes developer terminal activity.
 Your job is to interpret summaries of shell commands and generate a concise, human-readable explanation.
 Focus on intent and patterns rather than individual commands.
 Keep your output short (2–4 sentences) and natural.
 If the input is unclear or minimal, indicate that concisely.
"""

	let model = SystemLanguageModel.default
	
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
