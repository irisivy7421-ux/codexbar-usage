import Foundation
import Combine

struct UsageWindow: Equatable {
    let durationMinutes: Int?
    let usedPercent: Int
    let resetsAt: Date?

    var remainingPercent: Int { min(100, max(0, 100 - usedPercent)) }
}

struct ResetCredit: Identifiable, Equatable {
    let id: String
    let expiresAt: Date?
}

struct UsageSnapshot: Equatable {
    let windows: [UsageWindow]
    let resetCreditsAvailable: Int
    let resetCredits: [ResetCredit]

    var fiveHour: UsageWindow? { windows.first { ($0.durationMinutes ?? 0) >= 240 && ($0.durationMinutes ?? 0) <= 360 } }
    var weekly: UsageWindow? { windows.first { ($0.durationMinutes ?? 0) >= 9_000 && ($0.durationMinutes ?? 0) <= 11_000 } }
    var nearestCreditExpiry: Date? { resetCredits.compactMap(\.expiresAt).min() }
}

@MainActor
final class UsageStore: ObservableObject {
    @Published private(set) var snapshot: UsageSnapshot?
    @Published private(set) var errorMessage: String?
    @Published private(set) var updatedAt: Date?

    private let client = CodexAppServerClient()
    private var refreshTimer: Timer?

    init() {
        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    deinit { refreshTimer?.invalidate() }

    var menuBarText: String {
        guard let snapshot else { return errorMessage == nil ? "…" : "—" }
        var parts: [String] = []
        if let fiveHour = snapshot.fiveHour { parts.append("\(fiveHour.remainingPercent)") }
        if let weekly = snapshot.weekly { parts.append("W\(weekly.remainingPercent)") }
        if snapshot.resetCreditsAvailable > 0 {
            parts.append("R\(snapshot.resetCreditsAvailable)")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " · ")
    }

    func refresh() {
        Task {
            do {
                snapshot = try await client.readUsage()
                updatedAt = .now
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func windowText(label: String, window: UsageWindow) -> String {
        "\(label) \(window.remainingPercent)% ↻\(resetText(window.resetsAt))"
    }

    func resetText(_ date: Date?) -> String {
        guard let date else { return "—" }
        let remaining = date.timeIntervalSinceNow
        if remaining > 3_600 {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "EEE HH:mm"
            return formatter.string(from: date)
        }
        return relativeTime(date)
    }

    func relativeTime(_ date: Date) -> String {
        let seconds = max(0, Int(date.timeIntervalSinceNow))
        if seconds >= 86_400 { return "\(seconds / 86_400)d" }
        if seconds >= 3_600 { return "\(seconds / 3_600)h" }
        return "\(max(1, seconds / 60))m"
    }
}
