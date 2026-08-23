#if canImport(Foundation)
import Foundation
import WiserOneCore

/// Stateful quote selection service used by the UI.
final class QuoteService {
    private let repository: QuoteRepository

    private(set) var sourceSummary = ""
    private(set) var activeQuotes = [Quote]()
    private(set) var activeQuoteIndex = 0

    init(repository: QuoteRepository) {
        self.repository = repository
    }

    var hasLoadedQuotes: Bool {
        !activeQuotes.isEmpty
    }

    func loadDailyQuote(dayNumber: Int) -> Quote {
        do {
            let (quotes, sourceCount) = try repository.loadDiscoveredQuotes()
            guard !quotes.isEmpty else {
                resetState()
                return Quote.fallback
            }

            guard let boundedIndex = QuoteRotation.index(
                forDayNumber: dayNumber, poolSize: quotes.count
            ) else {
                resetState()
                return Quote.fallback
            }
            sourceSummary = sourceCount == 1 ? "1 source file" : "\(sourceCount) source files"
            activeQuotes = quotes
            activeQuoteIndex = boundedIndex
            return quotes[boundedIndex]
        } catch {
            resetState()
            return Quote.fallback
        }
    }

    func cycleToNextQuote() -> Quote? {
        guard !activeQuotes.isEmpty else {
            return nil
        }

        if activeQuotes.count == 1 {
            return activeQuotes[0]
        }

        activeQuoteIndex = (activeQuoteIndex + 1) % activeQuotes.count
        assert(activeQuoteIndex >= 0 && activeQuoteIndex < activeQuotes.count, "Quote index must remain in bounds.")
        return activeQuotes[activeQuoteIndex]
    }

    func currentQuote() -> Quote? {
        guard !activeQuotes.isEmpty else {
            return nil
        }

        guard activeQuoteIndex >= 0 && activeQuoteIndex < activeQuotes.count else {
            return nil
        }

        return activeQuotes[activeQuoteIndex]
    }

    private func resetState() {
        sourceSummary = ""
        activeQuotes = []
        activeQuoteIndex = 0
    }
}
#endif
