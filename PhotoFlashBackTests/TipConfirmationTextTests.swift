import XCTest
@testable import PhotoFlashBack

final class TipConfirmationTextTests: XCTestCase {
    private func price(_ amount: String, locale identifier: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: identifier)
        return formatter.string(from: NSDecimalNumber(string: amount))!
    }

    func testUsesTheStorefrontPriceInJapan() {
        let displayPrice = price("120", locale: "ja_JP")
        let message = TipConfirmationText.message(displayPrice: displayPrice)
        XCTAssertTrue(message.contains(displayPrice), message)
        XCTAssertTrue(message.contains("120"), message)
        XCTAssertFalse(message.contains("$"), message)
    }

    func testUsesTheStorefrontPriceInGermany() {
        let displayPrice = price("1.19", locale: "de_DE")
        let message = TipConfirmationText.message(displayPrice: displayPrice)
        XCTAssertTrue(message.contains(displayPrice), message)
        XCTAssertTrue(message.contains("€"), message)
        XCTAssertFalse(message.contains("$0.99"), message)
    }

    func testUsesTheStorefrontPriceInTheUS() {
        XCTAssertEqual(TipConfirmationText.message(displayPrice: price("0.99", locale: "en_US")),
                       "Would you like to send a $0.99 tip?")
    }

    func testMissingPriceFallsBackToGenericText() {
        let message = TipConfirmationText.message(displayPrice: "  ")
        XCTAssertEqual(message, "Would you like to send a tip?")
    }
}
