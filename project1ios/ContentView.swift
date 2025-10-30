import SwiftUI
import Combine
import UserNotifications

struct SavedTimer: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var isCountdown: Bool
    var displayMode: TimeDisplayMode = .default
}

enum TimeDisplayMode: String, Codable, CaseIterable, Identifiable {
    case `default`, years, months, days, hours, minutes, seconds
    
    var id: String { self.rawValue }
    var label: String {
        switch self {
        case .default: return "Default"
        case .years: return "Years"
        case .months: return "Months"
        case .days: return "Days"
        case .hours: return "Hours"
        case .minutes: return "Minutes"
        case .seconds: return "Seconds"
        }
    }
}

struct ContentView: View {
    @State private var timers: [SavedTimer] = []
    @State private var showingAddTimer = false
    @State private var now = Date()
    @State private var selectedTimer: SavedTimer?
    @State private var showingEditView = false

    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var countdownTimers: [SavedTimer] {
        timers.filter { $0.isCountdown }
    }

    var fromDateTimers: [SavedTimer] {
        timers.filter { !$0.isCountdown }
    }

    var body: some View {
        NavigationView {
            List {
                if !countdownTimers.isEmpty {
                    Section("Countdowns") {
                        ForEach(countdownTimers) { timer in
                            TimerRow(timer: timer, now: now)
                                .onTapGesture {
                                    selectedTimer = timer
                                    showingEditView = true
                                }
                        }
                        .onDelete { delete(at: $0, inCountdowns: true) }
                    }
                }

                if !fromDateTimers.isEmpty {
                    Section("From Dates") {
                        ForEach(fromDateTimers) { timer in
                            TimerRow(timer: timer, now: now)
                                .onTapGesture {
                                    selectedTimer = timer
                                    showingEditView = true
                                }
                        }
                        .onDelete { delete(at: $0, inCountdowns: false) }
                    }
                }
            }
            .navigationTitle("My Timers")
            .toolbar {
                Button(action: { showingAddTimer = true }) {
                    Image(systemName: "plus")
                }
            }
            .sheet(isPresented: $showingAddTimer) {
                AddTimerView { newTimer in
                    timers.append(newTimer)
                    saveTimers()
                    scheduleNotification(for: newTimer)
                }
            }
            .sheet(item: $selectedTimer) { timer in
                EditTimerView(timer: timer) { updated, deleted in
                    if deleted {
                        cancelNotification(for: timer)
                        timers.removeAll { $0.id == timer.id }
                    } else if let index = timers.firstIndex(where: { $0.id == timer.id }) {
                        cancelNotification(for: timers[index])
                        timers[index] = updated
                        scheduleNotification(for: updated)
                    }
                    saveTimers()
                }
            }
        }
        .onAppear {
            loadTimers()
            requestNotificationPermission()
        }
        .onReceive(timer) { _ in
            now = Date()
        }
    }

    // MARK: - Notifications
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("Notification permission error:", error)
            }
        }
    }

    private func scheduleNotification(for timer: SavedTimer) {
        guard timer.isCountdown else { return }

        let content = UNMutableNotificationContent()
        content.title = "Timer Finished"
        content.body = "\(timer.title) has arrived."
        content.sound = .default

        let triggerDate = timer.date
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: Calendar.current.dateComponents(
                [.year, .month, .day, .hour, .minute, .second],
                from: triggerDate
            ),
            repeats: false
        )

        let request = UNNotificationRequest(identifier: timer.id.uuidString, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func cancelNotification(for timer: SavedTimer) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [timer.id.uuidString])
    }

    // MARK: - CRUD
    private func delete(at offsets: IndexSet, inCountdowns: Bool) {
        let list = inCountdowns ? countdownTimers : fromDateTimers
        for index in offsets {
            let timerToDelete = list[index]
            cancelNotification(for: timerToDelete)
            if let realIndex = timers.firstIndex(of: timerToDelete) {
                timers.remove(at: realIndex)
            }
        }
        saveTimers()
    }

    private func saveTimers() {
        if let encoded = try? JSONEncoder().encode(timers) {
            UserDefaults.standard.set(encoded, forKey: "SavedTimers")
        }
    }

    private func loadTimers() {
        if let data = UserDefaults.standard.data(forKey: "SavedTimers"),
           let decoded = try? JSONDecoder().decode([SavedTimer].self, from: data) {
            timers = decoded
        }
    }
}

// MARK: - Timer Row
struct TimerRow: View {
    var timer: SavedTimer
    var now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(timer.title)
                .font(.headline)
            Text(timeDifferenceString())
                .font(.subheadline)
                .monospacedDigit()
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func timeDifferenceString() -> String {
        let fromDate = timer.isCountdown ? now : timer.date
        let toDate = timer.isCountdown ? timer.date : now
        if toDate < fromDate { return "Time's up" }

        let diff = toDate.timeIntervalSince(fromDate)

        switch timer.displayMode {
        case .years:
            let years = diff / (365.25 * 24 * 3600)
            return String(format: "%.2f years", years)
        case .months:
            let months = diff / (30.44 * 24 * 3600)
            return String(format: "%.2f months", months)
        case .days:
            let days = diff / (24 * 3600)
            return String(format: "%.0f days", days)
        case .hours:
            let hours = diff / 3600
            return String(format: "%.0f hours", hours)
        case .minutes:
            let minutes = diff / 60
            return String(format: "%.0f minutes", minutes)
        case .seconds:
            let seconds = diff
            return String(format: "%.0f seconds", seconds)
        case .default:
            return detailedDifference(from: fromDate, to: toDate)
        }
    }

    private func detailedDifference(from start: Date, to end: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second], from: start, to: end)
        var parts: [String] = []
        if let y = components.year, y > 0 { parts.append("\(y)y") }
        if let m = components.month, m > 0 { parts.append("\(m)mo") }
        if let d = components.day, d > 0 { parts.append("\(d)d") }
        if let h = components.hour, h > 0 { parts.append("\(h)h") }
        if let min = components.minute, min > 0 { parts.append("\(min)m") }
        if let s = components.second, s > 0 { parts.append("\(s)s") }
        return parts.joined(separator: " ")
    }
}

#Preview {
    ContentView()
}
