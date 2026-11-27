import ScriptureData
import Testing
@testable import ScriptureUI

@Suite struct NavigationHistoryTests {
    let mat5 = ChapterLocation(book: "MAT", chapter: 5)
    let rom8 = ChapterLocation(book: "ROM", chapter: 8)
    let psa23 = ChapterLocation(book: "PSA", chapter: 23)

    @Test func startsEmpty() {
        let history = NavigationHistory()
        #expect(history.current == nil)
        #expect(!history.canGoBack && !history.canGoForward)
    }

    @Test func goBackAndForward() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: rom8)
        #expect(history.canGoBack && !history.canGoForward)
        #expect(history.goBack() == mat5)
        #expect(history.current == mat5)
        #expect(history.canGoForward)
        #expect(history.goForward() == rom8)
        #expect(history.goForward() == nil)
    }

    @Test func newNavigationClearsForward() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: rom8)
        history.goBack()
        history.go(to: psa23)
        #expect(!history.canGoForward)
        #expect(history.goBack() == mat5)
    }

    @Test func sameLocationIsNotPushed() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.go(to: mat5)
        #expect(!history.canGoBack)
    }

    @Test func backRestoresTheVerseReadThere() {
        var history = NavigationHistory()
        history.go(to: mat5)
        history.updateCurrentVerse(17)
        history.go(to: rom8, verse: 4)
        #expect(history.currentVerse == 4)
        #expect(history.goBack() == mat5)
        #expect(history.currentVerse == 17)
        #expect(history.goForward() == rom8)
        #expect(history.currentVerse == 4)
    }

    @Test func backStackIsCapped() {
        var history = NavigationHistory()
        for chapter in 1...60 { history.go(to: ChapterLocation(book: "PSA", chapter: chapter)) }
        var steps = 0
        while history.goBack() != nil { steps += 1 }
        #expect(steps == 50)
    }
}
