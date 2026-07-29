import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    @State private var importAlertMessage: String? = nil
    @State private var showImportAlert = false

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
        .onAppear {
            RestTimerManager.shared.syncWithDatabase(modelContext: modelContext)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                RestTimerManager.shared.syncWithDatabase(modelContext: modelContext)
            } else if newPhase == .background || newPhase == .inactive {
                RestTimerManager.shared.saveToUserDefaults()
            }
        }
        .onOpenURL { url in
            handleOpenURL(url)
        }
        .alert("Routine Import", isPresented: $showImportAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(importAlertMessage ?? "")
        }
    }

    private func handleOpenURL(_ url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            let imported = try RoutineTransferService.decodeRoutines(from: data)
            for r in imported {
                modelContext.insert(r)
            }
            if imported.count == 1 {
                importAlertMessage = "Successfully imported routine: '\(imported[0].name)'"
            } else {
                importAlertMessage = "Successfully imported \(imported.count) routines."
            }
            showImportAlert = true
        } catch {
            importAlertMessage = "Failed to import routine: \(error.localizedDescription)"
            showImportAlert = true
        }
    }
}
