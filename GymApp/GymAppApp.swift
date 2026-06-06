import SwiftUI
import SwiftData

@main
struct GymAppApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Routine.self,
            ExerciseTemplate.self,
            WorkoutDay.self,
            WorkoutExercise.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            container = try ModelContainer(for: schema, configurations: config)
        } catch {
            // Schema changed in a way that cannot be auto-migrated — wipe the store
            // and start fresh so the app always has a working persistent container.
            let storeURL = config.url
            let shmURL = URL(fileURLWithPath: storeURL.path + "-shm")
            let walURL = URL(fileURLWithPath: storeURL.path + "-wal")
            try? FileManager.default.removeItem(at: storeURL)
            try? FileManager.default.removeItem(at: shmURL)
            try? FileManager.default.removeItem(at: walURL)

            do {
                container = try ModelContainer(for: schema, configurations: config)
            } catch {
                fatalError("Could not create ModelContainer after store reset: \(error)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
