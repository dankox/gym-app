import SwiftData
import Foundation

@Model
class WorkoutExercise {
    var name: String
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var sortOrder: Int
    var isCompleted: Bool
    var workoutDay: WorkoutDay?

    init(name: String, sets: Int, reps: Int, restSeconds: Int, sortOrder: Int = 0) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
        self.isCompleted = false
    }
}
