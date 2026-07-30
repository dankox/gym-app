import SwiftUI
import AudioToolbox
import UIKit
import SwiftData

struct ExerciseTimerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let initialExercise: WorkoutExercise
    @State private var selectedExerciseId: String

    init(exercise: WorkoutExercise) {
        self.initialExercise = exercise
        _selectedExerciseId = State(initialValue: exercise.id)
    }

    private var allExercises: [WorkoutExercise] {
        if let day = initialExercise.workoutDay {
            let sorted = day.exercises.sorted { $0.sortOrder < $1.sortOrder }
            if !sorted.isEmpty { return sorted }
        }
        let descriptor = FetchDescriptor<WorkoutDay>()
        if let days = try? modelContext.fetch(descriptor) {
            for day in days {
                let sorted = day.exercises.sorted { $0.sortOrder < $1.sortOrder }
                if sorted.contains(where: { $0.id == initialExercise.id }) {
                    return sorted
                }
            }
        }
        return [initialExercise]
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $selectedExerciseId) {
                ForEach(Array(allExercises.enumerated()), id: \.element.id) { index, ex in
                    SingleExerciseTimerView(
                        exercise: ex,
                        exerciseIndex: index,
                        totalExercises: allExercises.count
                    )
                    .tag(ex.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .navigationTitle("Rest Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Single Exercise Timer Page

struct SingleExerciseTimerView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var exercise: WorkoutExercise

    let exerciseIndex: Int
    let totalExercises: Int

    @State private var showNextPreview: Bool = false
    @State private var hasShownNextPreview: Bool = false

    private var timerManager: RestTimerManager {
        RestTimerManager.shared
    }

    private var isTimerActiveForThisExercise: Bool {
        timerManager.activeExerciseId == exercise.id && (timerManager.isTimerRunning || timerManager.isTimerPaused)
    }

    private var displayTimeRemaining: Int {
        if isTimerActiveForThisExercise {
            return timerManager.timeRemaining
        } else {
            return max(exercise.restSeconds, 1)
        }
    }

    private var displayTotalRestSeconds: Int {
        if isTimerActiveForThisExercise {
            return timerManager.totalRestSeconds
        } else {
            return max(exercise.restSeconds, 1)
        }
    }

    private var displayProgress: Double {
        if isTimerActiveForThisExercise {
            return timerManager.progress
        } else {
            return 1.0
        }
    }

    private var isTimerRunning: Bool {
        isTimerActiveForThisExercise && timerManager.isTimerRunning
    }

    private var isTimerPaused: Bool {
        isTimerActiveForThisExercise && timerManager.isTimerPaused
    }

    private var currentSetNumber: Int {
        min(exercise.currentCompletedSets + 1, exercise.sets)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Exercise Page Indicator (if multiple exercises)
                if totalExercises > 1 {
                    HStack(spacing: 8) {
                        if exerciseIndex > 0 {
                            Image(systemName: "chevron.left")
                                .font(.caption.bold())
                                .foregroundStyle(themeManager.accentColor)
                        } else {
                            Spacer().frame(width: 12)
                        }

                        Text("Exercise \(exerciseIndex + 1) of \(totalExercises)")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)

                        if exerciseIndex < totalExercises - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption.bold())
                                .foregroundStyle(themeManager.accentColor)
                        } else {
                            Spacer().frame(width: 12)
                        }
                    }
                }

                // Exercise Details Header or Next Exercise Preview
                ZStack {
                    exerciseHeaderCard
                        .opacity(showNextPreview ? 0.0 : 1.0)

                    if showNextPreview, let nextEx = nextExercise {
                        nextExerciseHeaderCard(nextEx: nextEx)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .clipped()

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
        .onAppear {
            timerManager.prepareTimer(for: exercise)
            timerManager.syncWithDatabase(modelContext: modelContext)
            triggerNextPreviewIfNeeded()
        }
        .onChange(of: timerManager.isTimerRunning) { _, isRunning in
            if isRunning {
                triggerNextPreviewIfNeeded()
            }
        }
        .onChange(of: timerManager.isTimerPaused) { _, isPaused in
            if !isPaused {
                triggerNextPreviewIfNeeded()
            }
        }
        .onChange(of: currentSetNumber) { _, _ in
            hasShownNextPreview = false
            triggerNextPreviewIfNeeded()
        }
        .onDisappear {
            showNextPreview = false
            hasShownNextPreview = false
        }
        .onChange(of: exercise.isCompleted) { _, isDone in
            if isDone {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    dismiss()
                }
            }
        }
    }

    private var isLongReps: Bool {
        exercise.reps.trimmingCharacters(in: .whitespaces).count > 15
    }

    private var nextExercise: WorkoutExercise? {
        if let day = exercise.workoutDay {
            let sorted = day.exercises.sorted { $0.sortOrder < $1.sortOrder }
            if let currentIndex = sorted.firstIndex(where: { $0.id == exercise.id }), currentIndex + 1 < sorted.count {
                return sorted[currentIndex + 1]
            }
        } else {
            let descriptor = FetchDescriptor<WorkoutDay>()
            if let days = try? modelContext.fetch(descriptor) {
                for day in days {
                    let sorted = day.exercises.sorted { $0.sortOrder < $1.sortOrder }
                    if let currentIndex = sorted.firstIndex(where: { $0.id == exercise.id }) {
                        if currentIndex + 1 < sorted.count {
                            return sorted[currentIndex + 1]
                        }
                    }
                }
            }
        }
        return nil
    }

    private func triggerNextPreviewIfNeeded() {
        guard isTimerActiveForThisExercise && timerManager.isTimerRunning && !timerManager.isTimerPaused else { return }
        guard currentSetNumber == exercise.sets else { return }
        guard nextExercise != nil else { return }

        // If exercise has auto-pause points (multiple rest periods), only show preview on the final rest period segment
        let pauseCount = exercise.currentPausePoints.count
        if pauseCount > 0 {
            guard timerManager.triggeredPausePoints.count >= pauseCount else { return }
        }

        guard !hasShownNextPreview else { return }

        hasShownNextPreview = true
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showNextPreview = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                showNextPreview = false
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

    private func nextExerciseHeaderCard(nextEx: WorkoutExercise) -> some View {
        let isLong = nextEx.reps.trimmingCharacters(in: .whitespaces).count > 15
        return VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "forward.fill")
                    .font(.caption.bold())
                Text("UP NEXT")
                    .font(.caption.bold())
            }
            .foregroundStyle(themeManager.secondaryColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(themeManager.secondaryColor.opacity(0.2), in: Capsule())

            Text(nextEx.name)
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                detailBadge(icon: "repeat", title: "Sets", value: "\(nextEx.sets)")
                if !isLong {
                    detailBadge(icon: "number", title: "Reps", value: "\(nextEx.reps)")
                }
                detailBadge(icon: "timer", title: "Rest", value: restLabel(for: nextEx.restSeconds))
                if !nextEx.currentPausePoints.isEmpty {
                    detailBadge(icon: "pause.circle.fill", title: "Pauses", value: "\(nextEx.currentPausePoints.count)")
                }
            }
            .padding(.top, 2)

            if isLong {
                detailBadge(icon: "number", title: "Reps", value: nextEx.reps)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(themeManager.secondaryColor.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(themeManager.secondaryColor.opacity(0.4), lineWidth: 1.5)
                )
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
        isTimerPaused ? themeManager.secondaryColor : themeManager.accentColor
    }

    private var timerDisplay: some View {
        Button {
            handleTimerCircleTap()
        } label: {
            ZStack {
                // Outer Ring Background
                Circle()
                    .stroke(activeTimerColor.opacity(0.2), lineWidth: 16)

                // Faded Background Play/Pause Icon
                Image(systemName: isTimerRunning ? (isTimerPaused ? "play.fill" : "pause.fill") : "play.fill")
                    .font(.system(size: 110, weight: .bold))
                    .foregroundStyle(activeTimerColor.opacity(0.12))
                    .offset(x: !isTimerRunning ? 5 : 0)

                // Progress Ring
                Circle()
                    .trim(from: 0, to: displayProgress)
                    .stroke(
                        activeTimerColor,
                        style: StrokeStyle(lineWidth: 16, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                // Pause Point Markers on Ring
                ForEach(exercise.currentPausePoints, id: \.self) { pp in
                    let remainingProgress = Double(displayTotalRestSeconds - pp) / Double(displayTotalRestSeconds)
                    let angleDegrees = remainingProgress * 360.0
                    let isPassed = isTimerActiveForThisExercise && timerManager.triggeredPausePoints.contains(pp)

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
                    Text(formatTime(displayTimeRemaining))
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.primary)

                    if let autoPauseMessage = isTimerActiveForThisExercise ? timerManager.autoPauseMessage : nil {
                        HStack(spacing: 4) {
                            Image(systemName: "pause.circle.fill")
                            Text(autoPauseMessage)
                        }
                        .font(.caption.bold())
                        .foregroundStyle(themeManager.secondaryColor)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(themeManager.secondaryColor.opacity(0.15), in: Capsule())
                    } else if isTimerRunning {
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
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .frame(width: 240, height: 240)
    }

    private func handleTimerCircleTap() {
        if !isTimerRunning && !isTimerPaused {
            timerManager.startTimer(for: exercise)
        } else if isTimerPaused {
            timerManager.resumeTimer()
        } else {
            timerManager.pauseTimer()
        }
    }

    // MARK: - Controls

    private var timerControls: some View {
        VStack(spacing: 12) {
            if !isTimerRunning && !isTimerPaused {
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
                    timerManager.completeCurrentSet(for: exercise, modelContext: modelContext)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 16) {
                    Button {
                        if isTimerPaused {
                            timerManager.resumeTimer()
                        } else {
                            timerManager.pauseTimer()
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
                        timerManager.completeCurrentSet(for: exercise, modelContext: modelContext)
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
