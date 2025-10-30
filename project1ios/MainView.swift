import SwiftUI

struct MainView: View {
    
    var calendarImg: String {
        let day = Calendar.current.component(.day, from: Date())
        return "\(day).calendar"
    }
    
    var body: some View {
        TabView {
            ContentView()
                .tabItem {
                    Label("Timers", systemImage: "hourglass")
                }
            
            NotesView()
                .tabItem {
                    Label("Notes", systemImage: "square.and.pencil")
                }
            
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: calendarImg)
                }
            
            TimeCalculatorView()
                .tabItem {
                    Label("Calculator", systemImage: "plus.forwardslash.minus")
                }
            
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}

#Preview {
    MainView()
}
