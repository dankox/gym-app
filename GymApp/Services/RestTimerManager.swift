import SwiftUI
import SwiftData
import AudioToolbox
import UIKit

@Observable
final class RestTimerManager {
    static let shared = RestTimerManager()

    var activeExerciseId: String? = nil
    var activeExercise: WorkoutExercise? = nil

    var totalRestSeconds: Int = 60
    var timeRemaining: Int = 60
    var progress: Double = 1.0
    var isTimerRunning: Bool = false
    var isTimerPaused: Bool = false
    var autoPauseMessage: String? = nil
    var triggeredPausePoints: Set<Int> = []

    var lastCompletedExerciseId: String? = nil
    var completionEventCount: Int = 0

    private var endDate: Date? = nil
    private var startDate: Date? = nil
    private var remainingDuration: Double = 60.0
    private var timer: Timer? = nil

    private init() {
        loadFromUserDefaults()
    }

    // MARK: - UserDefaults Keys
    private enum Keys {
        static let activeExerciseId = "rest_timer_active_exercise_id"
        static let totalRestSeconds = "rest_timer_total_rest_seconds"
        static let startDate = "rest_timer_start_date"
        static let endDate = "rest_timer_end_date"
        static let remainingDuration = "rest_timer_remaining_duration"
        static let isTimerRunning = "rest_timer_is_running"
        static let isTimerPaused = "rest_timer_is_paused"
        static let autoPauseMessage = "rest_timer_auto_pause_message"
        static let triggeredPausePoints = "rest_timer_triggered_pause_points"
    }

    // MARK: - Load & Save
    func loadFromUserDefaults() {
        let defaults = UserDefaults.standard
        activeExerciseId = defaults.string(forKey: Keys.activeExerciseId)
        totalRestSeconds = defaults.integer(forKey: Keys.totalRestSeconds)
        if totalRestSeconds <= 0 { totalRestSeconds = 60 }

        isTimerRunning = defaults.bool(forKey: Keys.isTimerRunning)
        isTimerPaused = defaults.bool(forKey: Keys.isTimerPaused)
        autoPauseMessage = defaults.string(forKey: Keys.autoPauseMessage)

        if let pausePointsArray = defaults.array(forKey: Keys.triggeredPausePoints) as? [Int] {
            triggeredPausePoints = Set(pausePointsArray)
        } else {
            triggeredPausePoints = []
        }

        let startTimestamp = defaults.double(forKey: Keys.startDate)
        if startTimestamp > 0 {
            startDate = Date(timeIntervalSince1970: startTimestamp)
        } else {
            startDate = nil
        }

        let endTimestamp = defaults.double(forKey: Keys.endDate)
        if endTimestamp > 0 {
            endDate = Date(timeIntervalSince1970: endTimestamp)
        } else {
            endDate = nil
        }

        remainingDuration = defaults.double(forKey: Keys.remainingDuration)
        if remainingDuration <= 0 && !isTimerRunning {
            remainingDuration = Double(totalRestSeconds)
        }
    }

    func saveToUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.set(activeExerciseId, forKey: Keys.activeExerciseId)
        defaults.set(totalRestSeconds, forKey: Keys.totalRestSeconds)
        defaults.set(isTimerRunning, forKey: Keys.isTimerRunning)
        defaults.set(isTimerPaused, forKey: Keys.isTimerPaused)
        defaults.set(autoPauseMessage, forKey: Keys.autoPauseMessage)
        defaults.set(Array(triggeredPausePoints), forKey: Keys.triggeredPausePoints)
        defaults.set(startDate?.timeIntervalSince1970 ?? 0, forKey: Keys.startDate)
        defaults.set(endDate?.timeIntervalSince1970 ?? 0, forKey: Keys.endDate)
        defaults.set(remainingDuration, forKey: Keys.remainingDuration)
    }

    // MARK: - Database Sync
    func syncWithDatabase(modelContext: ModelContext) {
        // If timer is already actively running or paused in memory with activeExercise, just update state
        if (isTimerRunning || isTimerPaused) && activeExercise != nil {
            updateState(modelContext: modelContext, playFeedback: false)
            return
        }

        loadFromUserDefaults()
        guard let activeId = activeExerciseId, !activeId.isEmpty else {
            return
        }

        if activeExercise?.id == activeId {
            updateState(modelContext: modelContext, playFeedback: false)
            return
        }

        let descriptor = FetchDescriptor<WorkoutExercise>(predicate: #Predicate { $0.id == activeId })
        if let exercise = (try? modelContext.fetch(descriptor))?.first {
            self.activeExercise = exercise
            if exercise.isCompleted {
                stopAndResetTimer()
                return
            }
            updateState(modelContext: modelContext, playFeedback: false)
        } else if isTimerRunning || isTimerPaused {
            updateState(modelContext: modelContext, playFeedback: false)
        }
    }

    // MARK: - Prepare Timer for View
    func prepareTimer(for exercise: WorkoutExercise) {
        if activeExerciseId == exercise.id && (isTimerRunning || isTimerPaused) {
            self.activeExercise = exercise
            return
        }

        if isTimerRunning || isTimerPaused {
            // A timer for another exercise is running or paused.
            // Do NOT stop it when merely opening another exercise's Rest Timer screen.
            return
        }

        self.activeExercise = exercise
        self.activeExerciseId = exercise.id
        self.totalRestSeconds = max(exercise.restSeconds, 1)
        self.remainingDuration = Double(self.totalRestSeconds)
        self.timeRemaining = self.totalRestSeconds
        self.progress = 1.0
        self.isTimerRunning = false
        self.isTimerPaused = false
        self.triggeredPausePoints = []
        self.autoPauseMessage = nil
        saveToUserDefaults()
    }

    // MARK: - Timer Actions
    func startTimer(for exercise: WorkoutExercise? = nil) {
        if let exercise = exercise {
            if activeExerciseId != exercise.id && (isTimerRunning || isTimerPaused) {
                stopAndResetTimer()
            }
            self.activeExercise = exercise
            self.activeExerciseId = exercise.id
        }
        guard let activeExercise = activeExercise else { return }

        let rest = max(activeExercise.restSeconds, 1)
        totalRestSeconds = rest
        remainingDuration = Double(rest)
        timeRemaining = rest
        progress = 1.0
        startDate = Date()
        endDate = Date().addingTimeInterval(remainingDuration)

        triggeredPausePoints.removeAll()
        autoPauseMessage = nil
        isTimerRunning = true
        isTimerPaused = false

        saveToUserDefaults()
        startHighFrequencyTimer()
    }

    func pauseTimer() {
        guard isTimerRunning && !isTimerPaused else { return }

        if let endDate = endDate {
            let diff = max(0, endDate.timeIntervalSince(Date()))
            remainingDuration = diff
            timeRemaining = Int(ceil(diff))
            progress = diff / Double(totalRestSeconds)
        }

        isTimerPaused = true
        stopHighFrequencyTimer()
        endDate = nil
        startDate = nil
        saveToUserDefaults()
    }

    func resumeTimer() {
        guard isTimerRunning && isTimerPaused else { return }

        autoPauseMessage = nil
        startDate = Date()
        endDate = Date().addingTimeInterval(remainingDuration)
        isTimerPaused = false

        saveToUserDefaults()
        startHighFrequencyTimer()
    }

    func stopAndResetTimer() {
        stopHighFrequencyTimer()
        activeExerciseId = nil
        activeExercise = nil
        isTimerRunning = false
        isTimerPaused = false
        endDate = nil
        startDate = nil
        remainingDuration = 60.0
        timeRemaining = 60
        progress = 1.0
        triggeredPausePoints.removeAll()
        autoPauseMessage = nil
        saveToUserDefaults()
    }

    func completeCurrentSet(for targetExercise: WorkoutExercise? = nil, modelContext: ModelContext, playFeedback: Bool = true) {
        let exerciseToComplete = targetExercise ?? activeExercise

        if playFeedback {
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            AudioServicesPlaySystemSound(1007)
        }

        guard let exercise = exerciseToComplete else {
            stopAndResetTimer()
            return
        }

        let isCompletingActiveTimer = (activeExerciseId == exercise.id)
        if isCompletingActiveTimer {
            stopHighFrequencyTimer()
        }

        let newCompleted = exercise.currentCompletedSets + 1
        exercise.completedSets = newCompleted

        lastCompletedExerciseId = exercise.id
        completionEventCount += 1

        if newCompleted >= exercise.sets {
            exercise.isCompleted = true
            if let day = exercise.workoutDay {
                if day.exercises.allSatisfy({ $0.isCompleted }) && day.workoutStartTime != nil {
                    let elapsed = max(1, Int(Date().timeIntervalSince(day.workoutStartTime!)))
                    day.durationSeconds = elapsed
                    day.workoutStartTime = nil
                    day.appendWorkoutDurationNote(durationSeconds: elapsed)
                }
            }
            try? modelContext.save()
            if isCompletingActiveTimer {
                stopAndResetTimer()
            }
        } else {
            if isCompletingActiveTimer {
                // Reset state for next set's rest
                isTimerRunning = false
                isTimerPaused = false
                endDate = nil
                startDate = nil
                triggeredPausePoints.removeAll()
                autoPauseMessage = nil
                totalRestSeconds = max(exercise.restSeconds, 1)
                remainingDuration = Double(totalRestSeconds)
                timeRemaining = totalRestSeconds
                progress = 1.0
                saveToUserDefaults()
            }
            try? modelContext.save()
        }
    }

    // MARK: - Update State
    func updateState(modelContext: ModelContext, playFeedback: Bool = false) {
        guard isTimerRunning else { return }

        if isTimerPaused {
            timeRemaining = Int(ceil(remainingDuration))
            progress = max(0.0, min(1.0, remainingDuration / Double(totalRestSeconds)))
            return
        }

        if self.endDate == nil {
            if let startDate = startDate {
                self.endDate = startDate.addingTimeInterval(remainingDuration)
            } else {
                return
            }
        }

        guard let endDate = self.endDate else { return }

        let now = Date()
        let diff = endDate.timeIntervalSince(now)

        if diff > 0 {
            let start = startDate ?? now.addingTimeInterval(-(Double(totalRestSeconds) - diff))
            let elapsedTotal = now.timeIntervalSince(start)

            if let exercise = activeExercise {
                let sortedPausePoints = exercise.currentPausePoints.sorted()
                let untriggered = sortedPausePoints.filter { !triggeredPausePoints.contains($0) }

                for pp in untriggered {
                    if elapsedTotal >= Double(pp) {
                        triggeredPausePoints.insert(pp)

                        let freezeRemaining = Double(totalRestSeconds - pp)
                        remainingDuration = freezeRemaining
                        timeRemaining = totalRestSeconds - pp
                        progress = freezeRemaining / Double(totalRestSeconds)

                        isTimerPaused = true
                        self.endDate = nil
                        self.startDate = nil
                        stopHighFrequencyTimer()

                        autoPauseMessage = "Auto-paused after \(formatSeconds(pp)) rest"
                        saveToUserDefaults()

                        if playFeedback {
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.warning)
                            AudioServicesPlaySystemSound(1052)
                        }
                        return
                    }
                }
            }

            timeRemaining = Int(ceil(diff))
            progress = max(0.0, min(1.0, diff / Double(totalRestSeconds)))
            remainingDuration = diff

            startHighFrequencyTimer()
        } else {
            timeRemaining = 0
            progress = 0.0
            completeCurrentSet(modelContext: modelContext, playFeedback: playFeedback)
        }
    }

    // MARK: - High Frequency Timer
    private func startHighFrequencyTimer() {
        stopHighFrequencyTimer()
        guard isTimerRunning && !isTimerPaused else { return }
        let t = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func tick() {
        guard isTimerRunning && !isTimerPaused, let endDate = endDate else { return }
        let now = Date()
        let diff = endDate.timeIntervalSince(now)

        if diff > 0 {
            timeRemaining = Int(ceil(diff))
            progress = max(0.0, min(1.0, diff / Double(totalRestSeconds)))
            remainingDuration = diff

            if let exercise = activeExercise {
                let elapsed = Double(totalRestSeconds) - diff
                let sortedPausePoints = exercise.currentPausePoints.sorted()
                let untriggered = sortedPausePoints.filter { !triggeredPausePoints.contains($0) }

                for pp in untriggered {
                    if elapsed >= Double(pp) {
                        triggeredPausePoints.insert(pp)
                        let freezeRemaining = Double(totalRestSeconds - pp)
                        remainingDuration = freezeRemaining
                        timeRemaining = totalRestSeconds - pp
                        progress = freezeRemaining / Double(totalRestSeconds)

                        isTimerPaused = true
                        self.endDate = nil
                        self.startDate = nil
                        stopHighFrequencyTimer()

                        autoPauseMessage = "Auto-paused after \(formatSeconds(pp)) rest"
                        saveToUserDefaults()

                        let generator = UINotificationFeedbackGenerator()
                        generator.notificationOccurred(.warning)
                        AudioServicesPlaySystemSound(1052)
                        break
                    }
                }
            }
        } else {
            timeRemaining = 0
            progress = 0.0
            if let exercise = activeExercise, let context = exercise.modelContext {
                completeCurrentSet(modelContext: context, playFeedback: true)
            } else if let activeId = activeExerciseId, !activeId.isEmpty {
                if let exercise = activeExercise {
                    let newCompleted = exercise.currentCompletedSets + 1
                    exercise.completedSets = newCompleted
                    if newCompleted >= exercise.sets {
                        exercise.isCompleted = true
                    }
                }
                stopAndResetTimer()
            } else {
                stopAndResetTimer()
            }
        }
    }

    private func stopHighFrequencyTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }
}
