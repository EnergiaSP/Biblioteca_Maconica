import Foundation

enum ReadingMetricsController {
    static func progress(completed: Int, total: Int) -> Double {
        guard total > 0 else { return 0 }
        return min(max(Double(completed) / Double(total), 0), 1)
    }

    static func percentage(completed: Int, total: Int) -> Int {
        Int((progress(completed: completed, total: total) * 100).rounded())
    }
}
