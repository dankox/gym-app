import SwiftData
import Foundation

@Model
class ExerciseTemplate {
    var name: String
    var sets: Int
    var reps: Int
    var restSeconds: Int
    var sortOrder: Int
    var routine: Routine?

    init(name: String, sets: Int, reps: Int, restSeconds: Int, sortOrder: Int = 0) {
        self.name = name
        self.sets = sets
        self.reps = reps
        self.restSeconds = restSeconds
        self.sortOrder = sortOrder
    }
}
