import SwiftUI
import AudioToolbox
import UIKit

struct ExerciseTimerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Bindable var exercise: WorkoutExercise

    @Environment(\.dismiss) private var dismiss

    @State private var timeRemaining: Int
    @State private var totalRestSeconds: Int
    @State private var progress: Double = 1.0
    @State private var isTimerRunning: Bool = false
    @State private var isTimerPaused: Bool = false
    @State private var timer: Timer? = nil

    @State private var endDate: Date? = nil
    @State private var remainingDuration: Double = 0.0
    @State private var triggeredPausePoints: Set<Int> = []
    @State private var autoPauseMessage: String? = nil

    init(exercise: WorkoutExercise) {
        self.exercise = exercise
        let rest = max(exercise.restSeconds, 1)
        _totalRestSeconds = State(initialValue: rest)
        _timeRemaining = State(initialValue: rest)
        _progress = State(initialValue: 1.0)
        _remainingDuration = State(initialValue: Double(rest))
    }

    private var currentSetNumber: Int {
        min(exercise.currentCompletedSets + 1, exercise.sets)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Exercise Details Header
                exerciseHeaderCard

                Spacer()

                // Timer Visual Ring & Countdown
                timerDisplay

                Spacer()

                // Control Buttons
                timerControls

                Spacer(minLength: 16)
            }
            .padding()
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        stopTimer()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                stopTimer()
            }
        }
    }

    private var isLongReps: Bool {
        exercise.reps.trimmingCharacters(in: .whitespaces).count > 15
    }

    // MARK: - Exercise Header Card

    private var exerciseHeaderCard: some View {
        VStack(spacing: 10) {
            Text(exercise.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                detailBadge(icon: "repeat", title: "Set", value: "\(currentSetNumber) of \(exercise.sets)")
                if !isLongReps {
                    detailBadge(icon: "number", title: "Reps", value: "\(exercise.reps)")
                }
                detailBadge(icon: "timer", title: "Rest", value: restLabel(for: exercise.restSeconds))
                if !exercise.currentPausePoints.isEmpty {
                    detailBadge(icon: "pause.circle.fill", title: "Pauses", value: "\(exercise.currentPausePoints.count)")
                }
            }
            .padding(.top, 4)

            if isLongReps {
                detailBadge(icon: "number", title: "Reps", value: exercise.reps)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.accentColor.opacity(0.1))
        )
    }

    private func detailBadge(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
            }
            .font(.caption)
            .foregroundStyle(.secondary)

            Text(value)
                .font(.subheadline.bold())
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    // MARK: - Timer Ring & Display

    private var timerDisplay: some View {
        ZStack {
            // Outer Ring Background
            Circle()
                .stroke(themeManager.accentColor.opacity(0.2), lineWidth: 16)

            // Progress Ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    themeManager.accentColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Pause Point Markers on Ring
            ForEach(exercise.currentPausePoints, id: \.self) { pp in
                let remainingProgress = Double(totalRestSeconds - pp) / Double(totalRestSeconds)
                let angleDegrees = remainingProgress * 360.0
                let isPassed = triggeredPausePoints.contains(pp)

                Circle()
                    .fill(isPassed ? Color.secondary : themeManager.secondaryColor)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Color.white, lineWidth: 2)
                    )
                    .offset(y: -120)
                    .rotationEffect(.degrees(angleDegrees))
            }

            VStack(spacing: 8) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()

                if let autoPauseMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                        Text(autoPauseMessage)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(themeManager.secondaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryColor.opacity(0.15), in: Capsule())
                } else if isTimerRunning && !isTimerPaused {
                    Text("Resting...")
                        .font(.headline)
                        .foregroundStyle(themeManager.accentColor)
                } else if isTimerPaused {
                    Text("Paused")
                        .font(.headline)
                        .foregroundStyle(themeManager.secondaryColor)
                } else if exercise.currentCompletedSets >= exercise.sets {
                    Text("All sets completed!")
                        .font(.headline)
                        .foregroundStyle(themeManager.completedColor)
                } else {
                    Text("Ready for Set \(currentSetNumber) Rest")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(width: 240, height: 240)
    }

    // MARK: - Controls

    private var timerControls: some View {
        VStack(spacing: 12) {
            if !isTimerRunning && !isTimerPaused {
                Button {
                    startTimer()
                } label: {
                    Label("Start Rest Timer", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip Rest & Complete Set") {
                    completeCurrentSet()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    Button {
                        if isTimerPaused {
                            resumeTimer()
                        } else {
                            pauseTimer()
                        }
                    } label: {
                        Label(
                            isTimerPaused ? "Resume" : "Pause",
                            systemImage: isTimerPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Complete Set Now") {
                        completeCurrentSet()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: 280)
    }

    // MARK: - Timer Logic

    private func startHighFrequencyTimer() {
        timer?.invalidate()
        let t = Timer(timeInterval: 0.03, repeats: true) { _ in
            updateTimer()
        }
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func updateTimer() {
        guard let endDate = endDate else { return }
        let now = Date()
        let diff = endDate.timeIntervalSince(now)

        if diff > 0 {
            timeRemaining = Int(ceil(diff))
            progress = diff / Double(totalRestSeconds)

            // Check auto-pause points
            let elapsed = Double(totalRestSeconds) - diff
            let sortedPausePoints = exercise.currentPausePoints.sorted()

            for pp in sortedPausePoints {
                if elapsed >= Double(pp) && !triggeredPausePoints.contains(pp) {
                    triggeredPausePoints.insert(pp)

                    // Freeze exact diff & remainingDuration
                    remainingDuration = diff
                    timeRemaining = Int(ceil(diff))
                    progress = diff / Double(totalRestSeconds)

                    isTimerPaused = true
                    timer?.invalidate()
                    timer = nil
                    self.endDate = nil

                    autoPauseMessage = "Auto-paused after \(formatSeconds(pp)) rest"

                    // Audio & Haptic Feedback
                    let generator = UINotificationFeedbackGenerator()
                    generator.notificationOccurred(.warning)
                    AudioServicesPlaySystemSound(1052)
                    break
                }
            }
        } else {
            timeRemaining = 0
            progress = 0.0
            timer?.invalidate()
            timer = nil
            completeCurrentSet()
        }
    }

    private func startTimer() {
        let duration = Double(totalRestSeconds)
        remainingDuration = duration
        endDate = Date().addingTimeInterval(duration)

        triggeredPausePoints.removeAll()
        autoPauseMessage = nil
        isTimerRunning = true
        isTimerPaused = false

        startHighFrequencyTimer()
    }

    private func pauseTimer() {
        guard isTimerRunning && !isTimerPaused else { return }

        if let endDate = endDate {
            let diff = max(0, endDate.timeIntervalSince(Date()))
            remainingDuration = diff
            timeRemaining = Int(ceil(diff))
            progress = diff / Double(totalRestSeconds)
        }

        isTimerPaused = true
        timer?.invalidate()
        timer = nil
        endDate = nil
    }

    private func resumeTimer() {
        guard isTimerRunning && isTimerPaused else { return }

        autoPauseMessage = nil
        endDate = Date().addingTimeInterval(remainingDuration)
        isTimerPaused = false

        startHighFrequencyTimer()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isTimerPaused = false
        endDate = nil
        remainingDuration = Double(totalRestSeconds)
        timeRemaining = totalRestSeconds
        progress = 1.0
        triggeredPausePoints.removeAll()
        autoPauseMessage = nil
    }

    private func completeCurrentSet() {
        stopTimer()

        // Audio & Haptic Feedback
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        AudioServicesPlaySystemSound(1007)

        // Increment completed sets count
        let newCompleted = exercise.currentCompletedSets + 1
        exercise.completedSets = newCompleted

        // Reset timer display for the next set
        timeRemaining = totalRestSeconds

        // If completed all sets, mark exercise as completed and close window
        if newCompleted >= exercise.sets {
            exercise.isCompleted = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                dismiss()
            }
        }
    }

    // MARK: - Formatting Helpers

    private func formatSeconds(_ seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func restLabel(for seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }
        return "\(seconds)s"
    }
}
