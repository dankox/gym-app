import SwiftUI

struct ContentView: View {
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
        }
    }
}
