import SwiftUI

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        TabView {
            CalendarView()
                .tabItem {
                    Label("Calendar", systemImage: "calendar")
                }
            RoutineListView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }
            SettingsView()
                .tabItem {
                    Label("Theme & Settings", systemImage: "paintpalette.fill")
                }
        }
        .tint(themeManager.accentColor)
        .preferredColorScheme(themeManager.appearance.colorScheme)
    }
}
