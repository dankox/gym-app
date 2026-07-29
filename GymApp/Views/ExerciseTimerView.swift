import SwiftUI
import AudioToolbox
import UIKit
import SwiftData

struct ExerciseTimerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: WorkoutExercise

    private var timerManager: RestTimerManager {
        RestTimerManager.shared
    }

    private var currentSetNumber: Int {
        min(exercise.currentCompletedSets + 1, exercise.sets)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Exercise Details Header
                    exerciseHeaderCard

                    // Timer Visual Ring & Countdown
                    timerDisplay
                        .padding(.top, 4)

                    // Control Buttons
                    timerControls

                    // Exercise Notes (under timer controls)
                    if !exercise.currentNotes.isEmpty {
                        exerciseNoteCard
                            .padding(.top, 4)
                    }
                }
                .padding()
            }
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                timerManager.prepareTimer(for: exercise)
                timerManager.syncWithDatabase(modelContext: modelContext)
            }
            .onChange(of: exercise.isCompleted) { _, isDone in
                if isDone {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        dismiss()
                    }
                }
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

    // MARK: - Exercise Note Card

    private var exerciseNoteCard: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "note.text")
                .font(.body.bold())
                .foregroundStyle(themeManager.accentColor)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                Text("Note")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)

                Text(exercise.currentNotes)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.accentColor.opacity(0.08))
        )
        .padding(.horizontal, 8)
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

    private var activeTimerColor: Color {
        timerManager.isTimerPaused ? themeManager.secondaryColor : themeManager.accentColor
    }

    private var timerDisplay: some View {
        ZStack {
            // Outer Ring Background
            Circle()
                .stroke(activeTimerColor.opacity(0.2), lineWidth: 16)

            // Progress Ring
            Circle()
                .trim(from: 0, to: timerManager.progress)
                .stroke(
                    activeTimerColor,
                    style: StrokeStyle(lineWidth: 16, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Pause Point Markers on Ring
            ForEach(exercise.currentPausePoints, id: \.self) { pp in
                let remainingProgress = Double(timerManager.totalRestSeconds - pp) / Double(timerManager.totalRestSeconds)
                let angleDegrees = remainingProgress * 360.0
                let isPassed = timerManager.triggeredPausePoints.contains(pp)

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
                Text(formatTime(timerManager.timeRemaining))
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .monospacedDigit()

                if let autoPauseMessage = timerManager.autoPauseMessage {
                    HStack(spacing: 4) {
                        Image(systemName: "pause.circle.fill")
                        Text(autoPauseMessage)
                    }
                    .font(.caption.bold())
                    .foregroundStyle(themeManager.secondaryColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(themeManager.secondaryColor.opacity(0.15), in: Capsule())
                } else if timerManager.isTimerRunning && !timerManager.isTimerPaused {
                    Text("Resting...")
                        .font(.headline)
                        .foregroundStyle(themeManager.accentColor)
                } else if timerManager.isTimerPaused {
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
            if !timerManager.isTimerRunning && !timerManager.isTimerPaused {
                Button {
                    timerManager.startTimer(for: exercise)
                } label: {
                    Label("Start Rest Timer", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button("Skip Rest & Complete Set") {
                    timerManager.completeCurrentSet(modelContext: modelContext)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    Button {
                        if timerManager.isTimerPaused {
                            timerManager.resumeTimer()
                        } else {
                            timerManager.pauseTimer()
                        }
                    } label: {
                        Label(
                            timerManager.isTimerPaused ? "Resume" : "Pause",
                            systemImage: timerManager.isTimerPaused ? "play.fill" : "pause.fill"
                        )
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Complete Set Now") {
                        timerManager.completeCurrentSet(modelContext: modelContext)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
            }
        }
        .frame(maxWidth: 280)
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
