#if canImport(Foundation)
import Foundation

/// Model to store a quote payload.
struct Quote: Decodable {
    /// Position in the pool. The website selects by this, so it is what
    /// orders the corpus here too.
    let id: Int?
    let quoteText: String
    let author: String
    let dateAdded: String
    let imageUrl: String

    private enum CodingKeys: String, CodingKey {
        case id
        case quoteText = "quote_text"
        case author
        case dateAdded = "date_added"
        case imageUrl = "image_url"
    }

    static let fallback = Quote(
        id: nil,
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
