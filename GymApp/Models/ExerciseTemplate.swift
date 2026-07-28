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
    var notes: String?
    var routine: Routine?

    init(name: String, sets: Int, reps: String, restSeconds: Int, sortOrder: Int = 0, pausePoints: [Int]? = [], notes: String? = nil) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
        self.pausePoints = pausePoints ?? []
        self.notes = notes
    }

    var currentPausePoints: [Int] {
        pausePoints ?? []
    }

    var currentNotes: String {
        notes ?? ""
    }
}
