import SwiftUI

struct EditTimerView: View {
    @Environment(\.dismiss) var dismiss

    @State var timer: SavedTimer
    var onFinish: (SavedTimer, Bool) -> Void

    @State private var updatedTitle = ""
    @State private var updatedDate = Date()
    @State private var updatedMode = true
    @State private var updatedDisplayMode: TimeDisplayMode = .default

    var body: some View {
        NavigationView {
            Form {
                Section("Title") {
                    TextField("Event name", text: $updatedTitle)
                }

                Section("Date") {
                    DatePicker("Select date", selection: $updatedDate, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Mode") {
                    Picker("Type", selection: $updatedMode) {
                        Text("Countdown").tag(true)
                        Text("From date").tag(false)
                    }
                    .pickerStyle(.segmented)
                }

                Section("Display Mode") {
                    Picker("Show", selection: $updatedDisplayMode) {
                        ForEach(TimeDisplayMode.allCases) { mode in
                            Text(mode.label).tag(mode)
                        }
                    }
                }

                Section {
                    Button(role: .destructive) {
                        onFinish(timer, true)
                        dismiss()
                    } label: {
                        Text("Delete Timer")
                    }
                }
            }
            .navigationTitle("Edit Timer")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        timer.title = updatedTitle
                        timer.date = updatedDate
                        timer.isCountdown = updatedMode
                        timer.displayMode = updatedDisplayMode
                        onFinish(timer, false)
                        dismiss()
                    }
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                updatedTitle = timer.title
                updatedDate = timer.date
                updatedMode = timer.isCountdown
                updatedDisplayMode = timer.displayMode
            }
        }
    }
}

#Preview {
    EditTimerView(
        timer: SavedTimer(
            id: UUID(),
            title: "Example",
            date: Date(),
            isCountdown: true,
            displayMode: .default
        )
    ) { _, _ in }
}
