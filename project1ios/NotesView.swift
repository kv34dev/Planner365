import SwiftUI
import UserNotifications

// MARK: - Models

struct NoteItem: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var content: String
    var date: Date                 // main date (used when "Add to Calendar" = true)
    var addToCalendar: Bool
    var repeatDates: [Date]? = nil // independent repeat dates
}

struct CalendarEvent: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var date: Date
}

// MARK: - Notification Manager

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            // optionally handle result
        }
    }

    /// Remove any pending notifications for a note (all identifiers that start with note.id.uuidString)
    func removeNotification(id: UUID) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let relatedIDs = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(id.uuidString) }
            if !relatedIDs.isEmpty {
                center.removePendingNotificationRequests(withIdentifiers: relatedIDs)
            }
        }
    }

    /// Schedule notifications for:
    /// - main date (if addToCalendar == true)
    /// - every date in repeatDates (if present)
    /// Each scheduled request identifier begins with the note UUID so it can be removed later.
    func scheduleNotifications(for note: NoteItem) {
        // clear old
        removeNotification(id: note.id)

        let center = UNUserNotificationCenter.current()

        // Common content builder
        func contentBuilder(body: String? = nil) -> UNMutableNotificationContent {
            let content = UNMutableNotificationContent()
            content.title = note.title
            content.body = body ?? "Calendar reminder"
            content.sound = .default
            return content
        }

        // Schedule main date if requested
        if note.addToCalendar {
            // skip scheduling past notifications
            if note.date >= Date() {
                let content = contentBuilder()
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: note.date)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let request = UNNotificationRequest(identifier: "\(note.id.uuidString)_main", content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }
        }

        // Schedule repeat dates (independent from addToCalendar)
        if let repeats = note.repeatDates, !repeats.isEmpty {
            for (index, rDate) in repeats.enumerated() {
                // skip past dates
                if rDate < Date() { continue }
                let content = contentBuilder(body: "Reminder repeat")
                let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: rDate)
                let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
                let identifier = "\(note.id.uuidString)_repeat_\(index)"
                let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
                center.add(request, withCompletionHandler: nil)
            }
        }
    }
}

// MARK: - Calendar Manager

final class CalendarManager {
    static let shared = CalendarManager()
    private init() {}

    private let storageKey = "CalendarEvents"

    func addOrUpdateEvent(id: UUID, title: String, date: Date) {
        var events = loadEvents()
        if let idx = events.firstIndex(where: { $0.id == id }) {
            events[idx].title = title
            events[idx].date = date
        } else {
            events.append(CalendarEvent(id: id, title: title, date: date))
        }
        saveEvents(events)
    }

    func removeEvent(id: UUID) {
        var events = loadEvents()
        events.removeAll { $0.id == id }
        saveEvents(events)
    }

    func loadEvents() -> [CalendarEvent] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([CalendarEvent].self, from: data)) ?? []
    }

    private func saveEvents(_ events: [CalendarEvent]) {
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

// MARK: - Notes View

struct NotesView: View {
    @State private var notes: [NoteItem] = []
    @State private var showingNewNote = false
    @State private var editingNote: NoteItem? = nil

    var body: some View {
        NavigationView {
            List {
                if notes.isEmpty {
                    Text("No notes yet")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding()
                } else {
                    ForEach(notes) { note in
                        Button(action: {
                            editingNote = note
                        }) {
                            NoteRow(note: note)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .onDelete(perform: deleteNote)
                }
            }
            .navigationTitle("My Notes")
            // заменил toolbar на navigationBarItems
            .navigationBarItems(trailing:
                Button(action: { showingNewNote = true }) {
                    Image(systemName: "plus")
                }
            )
            .sheet(isPresented: $showingNewNote) {
                AddNoteView(existingNote: nil) { note in
                    // Save new
                    notes.append(note)
                    saveNotes()
                    // Schedule notifications if needed
                    if note.addToCalendar || (note.repeatDates?.isEmpty == false) {
                        if note.addToCalendar {
                            CalendarManager.shared.addOrUpdateEvent(id: note.id, title: note.title, date: note.date)
                        }
                        NotificationManager.shared.scheduleNotifications(for: note)
                    }
                    showingNewNote = false
                } onDelete: { _ in
                    // nothing for new note
                }
            }
            .sheet(item: $editingNote) { note in
                AddNoteView(existingNote: note) { updated in
                    // Update saved array
                    if let idx = notes.firstIndex(where: { $0.id == updated.id }) {
                        notes[idx] = updated
                    } else {
                        notes.append(updated)
                    }
                    saveNotes()

                    // Update calendar events & notifications
                    if updated.addToCalendar {
                        CalendarManager.shared.addOrUpdateEvent(id: updated.id, title: updated.title, date: updated.date)
                    } else {
                        CalendarManager.shared.removeEvent(id: updated.id)
                    }

                    if updated.addToCalendar || (updated.repeatDates?.isEmpty == false) {
                        NotificationManager.shared.scheduleNotifications(for: updated)
                    } else {
                        NotificationManager.shared.removeNotification(id: updated.id)
                    }

                    editingNote = nil
                } onDelete: { noteToDelete in
                    deleteSpecific(noteToDelete)
                    editingNote = nil
                }
            }
            .onAppear {
                loadNotes()
                NotificationManager.shared.requestPermission()
            }
        }
    }

    private func deleteSpecific(_ note: NoteItem) {
        notes.removeAll { $0.id == note.id }
        if note.addToCalendar {
            CalendarManager.shared.removeEvent(id: note.id)
        }
        NotificationManager.shared.removeNotification(id: note.id)
        saveNotes()
    }

    private func saveNotes() {
        if let encoded = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(encoded, forKey: "SavedNotes")
        }
    }

    private func loadNotes() {
        if let data = UserDefaults.standard.data(forKey: "SavedNotes"),
           let decoded = try? JSONDecoder().decode([NoteItem].self, from: data) {
            notes = decoded
        } else {
            notes = []
        }
    }

    private func deleteNote(at offsets: IndexSet) {
        for idx in offsets {
            let note = notes[idx]
            if note.addToCalendar {
                CalendarManager.shared.removeEvent(id: note.id)
            }
            NotificationManager.shared.removeNotification(id: note.id)
        }
        notes.remove(atOffsets: offsets)
        saveNotes()
    }
}

// MARK: - Note Row

struct NoteRow: View {
    var note: NoteItem

    private var nextRepeatText: String? {
        guard let repeats = note.repeatDates, !repeats.isEmpty else { return nil }
        let now = Date()
        // choose next upcoming repeat (>= now), otherwise earliest future in sorted
        let upcoming = repeats.filter { $0 >= now }.sorted()
        let next = upcoming.first ?? repeats.sorted().first
        guard let n = next else { return nil }
        // Format like "Apr 2, 18:00" or localized short format
        let formatted = n.formatted(date: .abbreviated, time: .shortened)
        return formatted
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(note.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                // icons on the right
                if note.repeatDates?.isEmpty == false {
                    Image(systemName: "list.bullet.clipboard")
                        .foregroundColor(.blue)
                }
                if note.addToCalendar {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                }
            }

            if !note.content.isEmpty {
                Text(note.content)
                    .font(.subheadline)
                    .lineLimit(2)
                    .foregroundColor(.secondary)
            }

            // Show upcoming repeat if exists, with icon at start
            if let next = nextRepeatText {
                HStack(spacing: 6) {
                    Text("Next: \(next)")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .padding(.top, 2)
            } else if note.addToCalendar {
                // show main date if no repeats
                Text(note.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(.top, 2)
            }

        }
        .padding(.vertical, 6)
    }
}

// MARK: - Repeat Item Model
struct RepeatItem: Identifiable, Equatable {
    let id = UUID()
    var date: Date
}

// MARK: - Add / Edit Note View
struct AddNoteView: View {
    var existingNote: NoteItem?
    var onSave: (NoteItem) -> Void
    var onDelete: (NoteItem) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var content = ""
    @State private var date = Date()
    @State private var addToCalendar = false
    @State private var repeatItems: [RepeatItem] = []

    var body: some View {
        NavigationView {
            Form {
                Section("Details") {
                    TextField("Title", text: $title)
                    TextEditor(text: $content)
                        .frame(minHeight: 120)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color(.quaternaryLabel).opacity(0.6)))
                }

                Section("Reminder") {
                    Toggle("Add to Calendar", isOn: $addToCalendar)
                    if addToCalendar {
                        DatePicker("Date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                    }
                }

                Section("Repeat") {
                    ForEach($repeatItems) { $item in
                        RepeatRow(date: $item.date) {
                            withAnimation {
                                if let index = repeatItems.firstIndex(where: { $0.id == item.id }) {
                                    repeatItems.remove(at: index)
                                }
                            }
                        }
                    }

                    Button {
                        withAnimation { repeatItems.append(RepeatItem(date: Date())) }
                    } label: {
                        Label("Add Another Date", systemImage: "plus.circle.fill")
                    }
                }

                if existingNote != nil {
                    Section {
                        Button(role: .destructive) {
                            let noteToDelete = NoteItem(
                                id: existingNote!.id,
                                title: title,
                                content: content,
                                date: date,
                                addToCalendar: addToCalendar,
                                repeatDates: repeatItems.map { $0.date }.isEmpty ? nil : repeatItems.map { $0.date }
                            )
                            onDelete(noteToDelete)
                            dismiss()
                        } label: {
                            Text("Delete Note")
                        }
                    }
                }
            }
            .navigationTitle(existingNote == nil ? "New Note" : "Edit Note")
            .navigationBarItems(
                leading: Button("Cancel") { dismiss() },
                trailing: Button("Save") {
                    let note = NoteItem(
                        id: existingNote?.id ?? UUID(),
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        content: content,
                        date: date,
                        addToCalendar: addToCalendar,
                        repeatDates: repeatItems.map { $0.date }.isEmpty ? nil : repeatItems.map { $0.date }
                    )
                    onSave(note)
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            )
            .onAppear {
                if let note = existingNote {
                    title = note.title
                    content = note.content
                    date = note.date
                    addToCalendar = note.addToCalendar
                    repeatItems = (note.repeatDates ?? []).map { RepeatItem(date: $0) }
                }
            }
        }
    }
}

// MARK: - Repeat Row Component
struct RepeatRow: View {
    @Binding var date: Date
    var onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            DatePicker(
                "",
                selection: $date,
                displayedComponents: [.date, .hourAndMinute]
            )
            .labelsHidden()
            .datePickerStyle(.compact)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.leading, -4) // сдвигаем немного левее, чтобы начать от края

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
    }
}

// MARK: - Preview

struct NotesView_Previews: PreviewProvider {
    static var previews: some View {
        NotesView()
    }
}
