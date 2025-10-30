import SwiftUI

extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}

struct TimeCalculatorView: View {
    @State private var times: [TimeInput] = [TimeInput(), TimeInput()]
    @State private var result = "--:--:--"
    @State private var errorMessage: String? = nil

    var body: some View {
        NavigationView {
            VStack(spacing: 18) {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(times.indices, id: \.self) { index in
                            TimeInputBlock(
                                title: "Time \(index + 1)",
                                hours: $times[index].hours,
                                minutes: $times[index].minutes,
                                seconds: $times[index].seconds,
                                operation: $times[index].operation,
                                showOperationPicker: index > 0
                            )
                        }
                        .padding(.horizontal)

                        Button(action: { times.append(TimeInput()) }) {
                            Label("Add another time", systemImage: "plus.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.accentColor)
                        }
                        .padding(.top, 4)
                    }
                }
                .onTapGesture {
                    self.hideKeyboard()
                }

                if let err = errorMessage {
                    Text(err)
                        .foregroundColor(.red)
                        .font(.system(size: 13, weight: .regular))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 12) {
                    Button(action: calculate) {
                        Text("Calculate")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.accentColor)
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .shadow(color: .accentColor.opacity(0.25), radius: 6, x: 0, y: 3)
                    }

                    Button(action: reset) {
                        Text("Reset")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.tertiarySystemFill))
                            .foregroundColor(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                            .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
                    }
                }
                .padding(.horizontal)

                VStack(spacing: 6) {
                    Text("Result")
                        .font(.system(size: 15, weight: .regular))
                        .foregroundColor(.secondary)
                    Text(result)
                        .font(.system(size: 38, weight: .regular, design: .rounded))
                        .foregroundColor(.primary)
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                        .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 3)
                }
                .padding(.horizontal)

                Spacer(minLength: 10)
            }
            .padding(.top, 10)
            .navigationTitle("Time Calculator")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
        }
    }

    // MARK: - Logic

    func calculate() {
        errorMessage = nil
        guard !times.isEmpty else {
            errorMessage = "Add at least one time."
            return
        }

        var total: Double = 0
        var firstSet = false

        for t in times {
            guard let seconds = toSeconds(h: t.hours, m: t.minutes, s: t.seconds) else {
                errorMessage = "Invalid input: use only numbers 0–9999."
                return
            }

            if !firstSet {
                total = seconds
                firstSet = true
            } else {
                if t.operation == "+" {
                    total += seconds
                } else {
                    total -= seconds
                    if total < 0 { total = 0 }
                }
            }
        }

        result = formatTime(seconds: total)
    }

    func reset() {
        times = [TimeInput(), TimeInput()]
        result = "--:--:--"
        errorMessage = nil
    }

    func toSeconds(h: String, m: String, s: String) -> Double? {
        let hi = Int(h.trimmingCharacters(in: .whitespaces)) ?? 0
        let mi = Int(m.trimmingCharacters(in: .whitespaces)) ?? 0
        let si = Int(s.trimmingCharacters(in: .whitespaces)) ?? 0

        if hi < 0 || mi < 0 || si < 0 { return nil }
        if hi > 9999 || mi > 9999 || si > 9999 { return nil }

        return Double(hi * 3600 + mi * 60 + si)
    }

    func formatTime(seconds: Double) -> String {
        let total = Int(round(seconds))
        let hrs = total / 3600
        let mins = (total % 3600) / 60
        let secs = total % 60
        return String(format: "%02d:%02d:%02d", hrs, mins, secs)
    }
}

// MARK: - Data Model

struct TimeInput: Identifiable {
    let id = UUID()
    var hours = ""
    var minutes = ""
    var seconds = ""
    var operation = "+"
}

// MARK: - UI Components

struct TimeInputBlock: View {
    var title: String
    @Binding var hours: String
    @Binding var minutes: String
    @Binding var seconds: String
    @Binding var operation: String
    var showOperationPicker: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                if showOperationPicker {
                    Picker("", selection: $operation) {
                        Text("+").tag("+")
                        Text("−").tag("−")
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
                }
            }

            HStack(spacing: 10) {
                TimeField(label: "hh", value: $hours)
                TimeField(label: "mm", value: $minutes)
                TimeField(label: "ss", value: $seconds)
            }
            .padding(10)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
        }
    }
}

struct TimeField: View {
    var label: String
    @Binding var value: String

    var body: some View {
        VStack(spacing: 4) {
            TextField("0", text: $value)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 20, weight: .semibold, design: .rounded))
                .frame(width: 68, height: 42)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            Text(label)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Preview

struct TimeCalculatorView_Previews: PreviewProvider {
    static var previews: some View {
        TimeCalculatorView()
    }
}
