import SwiftData
import Foundation

@Model
class ExerciseTemplate {
    var name: String
    var sets: Int
    var reps: String
    var restSeconds: Int
    var sortOrder: Int
    var pausePoints: [Int]?
    var routine: Routine?

    init(name: String, sets: Int, reps: String, restSeconds: Int, sortOrder: Int = 0, pausePoints: [Int]? = []) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
        self.pausePoints = pausePoints ?? []
    }

    var currentPausePoints: [Int] {
        pausePoints ?? []
    }
}
