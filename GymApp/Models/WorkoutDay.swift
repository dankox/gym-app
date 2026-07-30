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

    func appendWorkoutDurationNote(durationSeconds: Int) {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd/MM/yy HH:mm"
        let timestamp = formatter.string(from: Date())
        let durationText = Self.formatDurationForNote(durationSeconds)
        let noteLine = "[\(timestamp)] Duration: \(durationText)"

        if let existing = notes, !existing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes = "\(existing)\n---\n\(noteLine)"
        } else {
            notes = noteLine
        }
    }

    private static func formatDurationForNote(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return "\(h)h \(m)m \(s)s"
        } else if m > 0 {
            return "\(m)m \(s)s"
        } else {
            return "\(s)s"
        }
    }
}
