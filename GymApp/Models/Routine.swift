import SwiftData
import Foundation

@Model
class Routine {
    var name: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var exercises: [ExerciseTemplate] = []

    init(name: String) {
        self.name = name
        self.createdAt = .now
    }
}
