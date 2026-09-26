import Foundation

@MainActor
final class AppNavigationController: ObservableObject {
    enum Tab: Int, CaseIterable {
        case inicio
        case colecoes
        case dossie
        case acervo
        case mais
    }

    @Published var selectedTab: Int
    @Published var moreScreen: TelaMais
    @Published var readingPath: [Int]
    @Published private(set) var readingStackID = UUID()
    /// Tab that opened the current reading, so closing it returns there instead of Home.
    @Published private(set) var readingReturnTab: Int?

    init(selectedTab: Int = Tab.inicio.rawValue, moreScreen: TelaMais = .menu, readingPath: [Int] = []) {
        self.selectedTab = selectedTab
        self.moreScreen = moreScreen
        self.readingPath = readingPath
    }

    func showHome() {
        let wasReading = !readingPath.isEmpty
        readingReturnTab = nil
        moreScreen = .menu
        readingPath.removeAll()
        selectedTab = Tab.inicio.rawValue
        // A simultaneous pop and tab change can leave a stale destination on iOS.
        if wasReading { readingStackID = UUID() }
    }

    func showLibrary() {
        readingReturnTab = nil
        readingPath.removeAll()
        selectedTab = Tab.acervo.rawValue
    }

    func showReading(itemID: Int) {
        if selectedTab != Tab.acervo.rawValue {
            readingReturnTab = selectedTab
        }
        readingPath = [itemID]
        selectedTab = Tab.acervo.rawValue
    }

    /// Closes the open reading and returns to the tab that opened it, keeping that tab's screen.
    func closeReading() {
        let wasReading = !readingPath.isEmpty
        readingPath.removeAll()
        guard let origin = readingReturnTab else { return }
        readingReturnTab = nil
        selectedTab = origin
        if wasReading { readingStackID = UUID() }
    }

    func forgetReadingOrigin() {
        readingReturnTab = nil
    }

    func showMore(_ screen: TelaMais = .menu) {
        moreScreen = screen
        selectedTab = Tab.mais.rawValue
    }
}
