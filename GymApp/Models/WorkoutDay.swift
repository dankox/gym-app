import SwiftData
import Foundation

@Model
class WorkoutDay {
    var date: Date
    var routineName: String
    var notes: String?
    var workoutStartTime: Date?
    var durationSeconds: Int?

    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []

    init(
        date: Date,
        routineName: String = "",
        notes: String? = nil,
        workoutStartTime: Date? = nil,
        durationSeconds: Int? = nil
    ) {
        self.date = date
        self.routineName = routineName
        self.notes = notes
        self.workoutStartTime = workoutStartTime
        self.durationSeconds = durationSeconds
    }
}
