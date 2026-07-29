import SwiftData
import Foundation

@Model
class WorkoutExercise {
    var id: String
    var name: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var sortOrder: Int
    var isCompleted: Bool
    var completedSets: Int?
    var routineName: String?
    var pausePoints: [Int]?
    var notes: String?
    var workoutDay: WorkoutDay?

    init(
        id: String = UUID().uuidString,
        name: String,
        sets: Int,
        reps: String,
        restSeconds: Int,
        sortOrder: Int = 0,
        completedSets: Int? = 0,
        routineName: String? = nil,
        pausePoints: [Int]? = [],
        notes: String? = nil
    ) {
        self.id = id
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
        self.isCompleted = false
        self.completedSets = completedSets
        self.routineName = routineName
        self.pausePoints = pausePoints ?? []
        self.notes = notes
    }

    var currentCompletedSets: Int {
        completedSets ?? 0
    }

    var currentPausePoints: [Int] {
        pausePoints ?? []
    }

    var currentNotes: String {
        notes ?? ""
    }
}
