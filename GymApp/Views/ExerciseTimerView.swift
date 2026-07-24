import SwiftUI
import AudioToolbox
import UIKit

struct ExerciseTimerView: View {
    @Bindable var exercise: WorkoutExercise

    @Environment(\.dismiss) private var dismiss

    @State private var timeRemaining: Int
    @State private var totalRestSeconds: Int
    @State private var progress: Double = 1.0
    @State private var isTimerRunning: Bool = false
    @State private var isTimerPaused: Bool = false
    @State private var timer: Timer? = nil

    init(exercise: WorkoutExercise) {
        self.exercise = exercise
        let rest = max(exercise.restSeconds, 1)
        _totalRestSeconds = State(initialValue: rest)
        _timeRemaining = State(initialValue: rest)
        _progress = State(initialValue: 1.0)
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

    // MARK: - Exercise Header Card

    private var exerciseHeaderCard: some View {
        VStack(spacing: 10) {
            Text(exercise.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                detailBadge(icon: "repeat", title: "Set", value: "\(currentSetNumber) of \(exercise.sets)")
                detailBadge(icon: "number", title: "Reps", value: "\(exercise.reps)")
                detailBadge(icon: "timer", title: "Rest", value: restLabel(for: exercise.restSeconds))
            }
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.1))
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
        }
    }

    // MARK: - Timer Ring & Display

    private var timerDisplay: some View {
        ZStack {
            // Outer Ring Background
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: 16)

            // Progress Ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.accentColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 8) {
                Text(formatTime(timeRemaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()

                if isTimerRunning && !isTimerPaused {
                    Text("Resting...")
                        .font(.headline)
                        .foregroundStyle(Color.accentColor)
                } else if isTimerPaused {
                    Text("Paused")
                        .font(.headline)
                        .foregroundStyle(.orange)
                } else if exercise.currentCompletedSets >= exercise.sets {
                    Text("All sets completed!")
                        .font(.headline)
                        .foregroundStyle(.green)
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

    private func startTimer() {
        timeRemaining = totalRestSeconds
        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            progress = 1.0
        }
        isTimerRunning = true
        isTimerPaused = false

        withAnimation(.linear(duration: Double(totalRestSeconds))) {
            progress = 0.0
        }

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                completeCurrentSet()
            }
        }
    }

    private func pauseTimer() {
        isTimerPaused = true
        timer?.invalidate()
        timer = nil

        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            progress = Double(timeRemaining) / Double(totalRestSeconds)
        }
    }

    private func resumeTimer() {
        isTimerPaused = false

        withAnimation(.linear(duration: Double(timeRemaining))) {
            progress = 0.0
        }

        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if timeRemaining > 1 {
                timeRemaining -= 1
            } else {
                timeRemaining = 0
                completeCurrentSet()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
        isTimerRunning = false
        isTimerPaused = false

        let transaction = Transaction(animation: nil)
        withTransaction(transaction) {
            progress = 1.0
        }
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
