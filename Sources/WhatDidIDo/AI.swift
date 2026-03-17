import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

@available(macOS 26.0, *)
@Generable
struct SummarizedSummary {
	@Guide(description: "You are given a summary of terminal activity. Produce a short, clear explanation of what the user was doing. Emphasize patterns and workflow rather than specific commands. Keep it natural, concise, and easy to read.")
	var summary: String
}

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
		if model.isAvailable {
			do {
				var prompt: String = ""
				
				for line in summary {
					prompt.append(line + "\n")
				}
				
				let session = LanguageModelSession(model: model, instructions: SummarizedSummaryCore.systemPrompt)
				let result = try await session.respond(to: prompt, generating: SummarizedSummary.self)
				
				return result.content.summary
			} catch {
				print("Error: \(error)")
			}
		} else {
			print("Not available: \(model.availability)")
		}
		
		return nil
	}
}
