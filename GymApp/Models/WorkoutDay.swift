import SwiftData
import Foundation

@Model
class WorkoutDay {
    var date: Date
    var routineName: String
    var notes: String?

    @Relationship(deleteRule: .cascade)
    var exercises: [WorkoutExercise] = []

    init(date: Date, routineName: String = "", notes: String? = nil) {
        self.date = date
        self.routineName = routineName
        self.notes = notes
    }
}
