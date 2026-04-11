#if canImport(Foundation)
import Foundation

/// Model to store a quote payload.
struct Quote: Decodable {
    let quoteText: String
    let author: String
    let dateAdded: String
    let imageUrl: String

    private enum CodingKeys: String, CodingKey {
        case quoteText = "quote_text"
        case author
        case dateAdded = "date_added"
        case imageUrl = "image_url"
    }

    static let fallback = Quote(
        quoteText: "Quote not found",
        author: "Author not found",
        dateAdded: "Date not found",
        imageUrl: "Image not found"
    )
}

/// Wrapper used for quote JSON decoding.
struct Quotes: Decodable {
    let quotes: [Quote]
}
#endif
