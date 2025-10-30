import SwiftUI

struct AddTimerView: View {
    @Environment(\.dismiss) var dismiss
    
    @State private var title = ""
    @State private var date = Date()
    @State private var isCountdown = true
    @State private var displayMode: TimeDisplayMode = .default
    
    var onSave: (SavedTimer) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section("Title") {
                    TextField("Event name", text: $title)
                }
                Section("Date") {
                    DatePicker("Select date", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                Section("Mode") {
                    Picker("Type", selection: $isCountdown) {
                        Text("Countdown").tag(true)
                        Text("From date").tag(false)
                    }
                    .pickerStyle(.segmented)
                }
                Section("Display Mode") {
                    Picker("Show", selection: $displayMode) {
                        ForEach(TimeDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }
            }
            .navigationTitle("Add Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let newTimer = SavedTimer(id: UUID(), title: title, date: date, isCountdown: isCountdown, displayMode: displayMode)
                        onSave(newTimer)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    AddTimerView { _ in }
}
