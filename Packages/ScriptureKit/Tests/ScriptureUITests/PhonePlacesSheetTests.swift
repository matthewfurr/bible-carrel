#if os(iOS)
import SwiftUI
import Testing
@testable import ScriptureUI

/// Matt's review, 2026-11-24: the phone's Places sheet never goes past half the screen, whether it holds the list or a
/// place's page, and a scroll inside it scrolls its content, never the sheet.
@Suite struct PhonePlacesSheetTests {
    @Test func theSheetsTallestDetentIsHalfThePage() {
        #expect(PhonePlacesScreen.detents == [.fraction(0.25), PhonePlacesScreen.tallest])
        #expect(PhonePlacesScreen.tallest == .fraction(PlacesSheet.tallestFraction))
        #expect(PlacesSheet.tallestFraction <= 0.5)
        #expect(!PhonePlacesScreen.detents.contains(.large))
        #expect(PhonePlacesScreen.detents.contains(PhonePlacesScreen.opening))
    }

    @Test func aScrollInsideTheSheetScrollsItsContent() {
        #expect(PhonePlacesScreen.contentInteraction == .scrolls)
    }
}
#endif
