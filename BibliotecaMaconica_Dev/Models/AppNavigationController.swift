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

    init(selectedTab: Int = Tab.inicio.rawValue, moreScreen: TelaMais = .menu, readingPath: [Int] = []) {
        self.selectedTab = selectedTab
        self.moreScreen = moreScreen
        self.readingPath = readingPath
    }

    func showHome() {
        let wasReading = !readingPath.isEmpty
        moreScreen = .menu
        readingPath.removeAll()
        selectedTab = Tab.inicio.rawValue
        // A simultaneous pop and tab change can leave a stale destination on iOS.
        if wasReading { readingStackID = UUID() }
    }

    func showLibrary() {
        readingPath.removeAll()
        selectedTab = Tab.acervo.rawValue
    }

    func showReading(itemID: Int) {
        readingPath = [itemID]
        selectedTab = Tab.acervo.rawValue
    }

    func showMore(_ screen: TelaMais = .menu) {
        moreScreen = screen
        selectedTab = Tab.mais.rawValue
    }
}
