import SwiftUI

struct CalendarView: View {
    @State private var selectedDate = Date()
    @State private var currentMonthOffset = 0
    @State private var events: [CalendarEvent] = []
    
    @State private var showingMonthPicker = false
    @State private var selectedEvent: CalendarEvent?
    
    var body: some View {
        VStack(spacing: 16) {
            // MARK: - Header (приклеен сверху)
            HStack {
                Button(action: { showingMonthPicker = true }) {
                    HStack(spacing: 4) {
                        Text(formattedMonthAndYear)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)
                    }
                }
                
                Spacer()
                
                Button(action: { withAnimation(.easeInOut) { currentMonthOffset -= 1 } }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
                
                Button(action: { withAnimation(.easeInOut) { currentMonthOffset += 1 } }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                        .frame(width: 34, height: 34)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .sheet(isPresented: $showingMonthPicker) {
                MonthYearPicker(selectedDate: $selectedDate, currentMonthOffset: $currentMonthOffset)
            }
            
            // MARK: - Weekday labels
            HStack(spacing: 0) {
                ForEach(["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"], id: \.self) { day in
                    Text(day.uppercased())
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.secondary)
                        .frame(width: UIScreen.main.bounds.width / 7)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 0)
            
            // MARK: - Days Grid
            let days = extractDays()
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 2), count: 7),
                spacing: 10
            ) {
                ForEach(days, id: \.self) { value in
                    if let value = value {
                        dayCell(for: value)
                            .frame(width: UIScreen.main.bounds.width / 7)
                    } else {
                        Color.clear
                            .frame(width: UIScreen.main.bounds.width / 7, height: 40)
                    }
                }
            }
            .padding(.horizontal, 0)
            
            // MARK: - Events Scrollable
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let filtered = events.filter {
                        Calendar.current.isDate($0.date, inSameDayAs: selectedDate)
                    }
                    
                    if filtered.isEmpty {
                        Text("No events for this day")
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 8)
                    } else {
                        ForEach(filtered) { event in
                            Button {
                                selectedEvent = event
                            } label: {
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(event.title)
                                            .font(.system(size: 16, weight: .medium))
                                        Text(event.date.formatted(date: .omitted, time: .shortened))
                                            .font(.system(size: 13))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(Color(.systemBackground))
                                .cornerRadius(30)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 10)
            }
            
            Spacer()
        }
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .onAppear(perform: loadEvents)
        .onReceive(NotificationCenter.default.publisher(for: .notesUpdated)) { _ in
            loadEvents()
        }
        .sheet(item: $selectedEvent) { event in
            EventDetailsView(event: event)
        }
    }
    
    // MARK: - Components
    
    private func dayCell(for date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDateInToday(date)
        let hasEvent = events.contains(where: { Calendar.current.isDate($0.date, inSameDayAs: date) })
        
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedDate = date
            }
        } label: {
            VStack {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(size: 17, weight: isSelected ? .bold : .regular))
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .foregroundColor(isSelected ? .white : (isToday ? .blue : .primary))
                    .background(
                        ZStack {
                            if isSelected {
                                Circle()
                                    .fill(Color.accentColor)
                                    .transition(.scale.combined(with: .opacity))
                            } else if isToday {
                                //Circle()
                                    //.stroke(Color.blue.opacity(0.6), lineWidth: 1.2)
                            }
                        }
                    )
                if hasEvent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 5, height: 5)
                        .padding(.top, -4)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Month and Days Logic
    
    private var currentMonthDate: Date {
        Calendar.current.date(byAdding: .month, value: currentMonthOffset, to: Date()) ?? Date()
    }
    
    private var formattedMonthAndYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: currentMonthDate).capitalized
    }
    
    private func extractDays() -> [Date?] {
        var calendar = Calendar.current
        calendar.firstWeekday = 2 // Monday
        
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: currentMonthDate))!
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!
        
        var days: [Date?] = []
        let weekdayOffset = (calendar.component(.weekday, from: startOfMonth) + 5) % 7
        
        // empty slots before the first day
        for _ in 0..<weekdayOffset {
            days.append(nil)
        }
        
        // actual days
        for day in range {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        return days
    }
    
    // MARK: - Load events
    private func loadEvents() {
        events = CalendarManager.shared.loadEvents()
    }
}

// MARK: - Picker for Month/Year

struct MonthYearPicker: View {
    @Binding var selectedDate: Date
    @Binding var currentMonthOffset: Int
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                DatePicker(
                    "Select Month and Year",
                    selection: $selectedDate,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .labelsHidden()
                .padding(.horizontal)
                .padding(.top)

                // MARK: - Today Button
                Button(action: {
                    selectedDate = Date()
                    currentMonthOffset = 0
                }) {
                    Text("Return to Today")
                        .font(.body)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.15))
                        .foregroundColor(.blue)
                        .cornerRadius(10)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .navigationTitle("Select Date")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        let monthsBetween = Calendar.current.dateComponents([.month], from: Date(), to: selectedDate).month ?? 0
                        currentMonthOffset = monthsBetween
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Event Details

struct EventDetailsView: View {
    let event: CalendarEvent
    @Environment(\.dismiss) var dismiss

    private struct SavedNoteStub: Codable {
        var id: UUID
        var title: String
        var content: String
        var date: Date
        var addToCalendar: Bool
    }

    private func findNoteContent() -> String? {
        guard let data = UserDefaults.standard.data(forKey: "SavedNotes"),
              let notes = try? JSONDecoder().decode([SavedNoteStub].self, from: data) else {
            return nil
        }
        return notes.first(where: { $0.id == event.id })?.content
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                Text(event.title)
                    .font(.title2.bold())
                Text(event.date.formatted(date: .abbreviated, time: .shortened))
                    .foregroundColor(.secondary)
                Divider()
                if let content = findNoteContent(), !content.isEmpty {
                    ScrollView {
                        Text(content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.bottom, 20)
                    }
                } else {
                    Text("No additional details.")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding()
            .navigationTitle("Event Details")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Notification Name Extension

extension Notification.Name {
    static let notesUpdated = Notification.Name("notesUpdated")
}

// MARK: - Preview

#Preview {
    NavigationView {
        CalendarView()
    }
}
