import SwiftUI
import SwiftData

// MARK: - Day Detail View (outer shell, queries for the day)

struct DayDetailView: View {
    let date: Date

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var workoutDays: [WorkoutDay]

    @State private var showRoutinePicker = false
    @State private var showDeleteConfirmation = false

    private var workoutDay: WorkoutDay? {
        workoutDays.first { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if let day = workoutDay {
                    WorkoutDayEditor(day: day)
                } else {
                    emptyContent
                }
            }
            .navigationTitle(
                date.formatted(.dateTime.weekday(.wide).day().month(.wide).year())
            )
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if workoutDay != nil {
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Image(systemName: "trash")
                            }
                            .tint(.red)
                        }
                        Button {
                            showRoutinePicker = true
                        } label: {
                            Label(
                                workoutDay == nil ? "Import Routine" : "Add Routine",
                                systemImage: workoutDay == nil ? "square.and.arrow.down" : "plus"
                            )
                        }
                    }
                }
            }
            .sheet(isPresented: $showRoutinePicker) {
                RoutinePickerView(date: date)
            }
            .confirmationDialog(
                "Remove Logged Workout",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    if let day = workoutDay {
                        modelContext.delete(day)
                        dismiss()
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove the logged workout for this day?")
            }
        }
    }

    // MARK: - Empty State

    var emptyContent: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No workout yet")
                    .font(.title2.bold())
                Text("Import a saved routine to get started.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button {
                showRoutinePicker = true
            } label: {
                Label("Import Exercise Routine", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }
}

// MARK: - Workout Day Editor (uses @Bindable for notes binding)

struct WorkoutDayEditor: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var day: WorkoutDay

    @State private var activeTimerExercise: WorkoutExercise? = nil
    @State private var exerciseToEdit: WorkoutExercise? = nil
    @FocusState private var isNotesFocused: Bool

    private var sortedExercises: [WorkoutExercise] {
        day.exercises.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var completedCount: Int {
        day.exercises.filter(\.isCompleted).count
    }

    private var routineGroups: [(name: String, exercises: [WorkoutExercise])] {
        var groups: [(name: String, exercises: [WorkoutExercise])] = []
        var groupDict: [String: [WorkoutExercise]] = [:]

        for exercise in sortedExercises {
            let key = exercise.routineName ?? ""
            groupDict[key, default: []].append(exercise)
        }

        var seenKeys = Set<String>()
        for exercise in sortedExercises {
            let key = exercise.routineName ?? ""
            if !seenKeys.contains(key) {
                seenKeys.insert(key)
                if let exList = groupDict[key] {
                    groups.append((name: key, exercises: exList))
                }
            }
        }
        return groups
    }

    // Bridge optional String? to the String that TextEditor requires.
    private var notesBinding: Binding<String> {
        Binding(
            get: { day.notes ?? "" },
            set: { day.notes = $0.isEmpty ? nil : $0 }
        )
    }

    private var hasNotes: Bool { !(day.notes ?? "").isEmpty }

    var body: some View {
        List {
            // Workout Timer Section
            workoutTimerSection

            // Exercises grouped by routine
            if sortedExercises.isEmpty {
                Section("Exercises") {
                    Text("No exercises")
                        .foregroundStyle(.secondary)
                        .italic()
                }
            } else if routineGroups.count > 1 || (routineGroups.count == 1 && !routineGroups[0].name.isEmpty) {
                ForEach(routineGroups, id: \.name) { group in
                    Section {
                        ForEach(group.exercises) { exercise in
                            WorkoutExerciseRow(
                                exercise: exercise,
                                onEdit: { ex in
                                    isNotesFocused = false
                                    exerciseToEdit = ex
                                },
                                onStartTimer: { ex in
                                    isNotesFocused = false
                                    activeTimerExercise = ex
                                }
                            )
                        }
                        .onDelete { offsets in
                            deleteExercises(in: group.exercises, at: offsets)
                        }
                    } header: {
                        routineGroupHeader(name: group.name, exercises: group.exercises)
                    }
                }
            } else {
                Section {
                    ForEach(sortedExercises) { exercise in
                        WorkoutExerciseRow(
                            exercise: exercise,
                            onEdit: { ex in
                                isNotesFocused = false
                                exerciseToEdit = ex
                            },
                            onStartTimer: { ex in
                                isNotesFocused = false
                                activeTimerExercise = ex
                            }
                        )
                    }
                    .onDelete { offsets in
                        deleteExercises(in: sortedExercises, at: offsets)
                    }
                } header: {
                    exercisesSectionHeader
                }
            }

            // Notes
            Section {
                ZStack(alignment: .topLeading) {
                    TextEditor(text: notesBinding)
                        .frame(minHeight: 110)
                        .focused($isNotesFocused)
                    if !hasNotes {
                        Text("Add notes for this workout…")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 8)
                            .padding(.leading, 5)
                            .allowsHitTesting(false)
                    }
                }
            } header: {
                Text("Notes")
            }
        }
        .listStyle(.insetGrouped)
        .scrollDismissesKeyboard(.immediately)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    isNotesFocused = false
                }
                .fontWeight(.semibold)
            }
        }
        .onAppear {
            RestTimerManager.shared.syncWithDatabase(modelContext: modelContext)
            checkAutoFinish(newCount: completedCount)
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                RestTimerManager.shared.syncWithDatabase(modelContext: modelContext)
            } else if newPhase == .background || newPhase == .inactive {
                RestTimerManager.shared.saveToUserDefaults()
            }
        }
        .onChange(of: completedCount) { _, newCount in
            checkAutoFinish(newCount: newCount)
        }
        .sheet(item: $activeTimerExercise) { exercise in
            ExerciseTimerView(exercise: exercise)
        }
        .sheet(item: $exerciseToEdit) { exercise in
            EditWorkoutExerciseView(exercise: exercise)
        }
    }

    // MARK: - Workout Timer Section

    @ViewBuilder
    private var workoutTimerSection: some View {
        Section("Workout Timer") {
            if let startTime = day.workoutStartTime {
                TimelineView(.periodic(from: startTime, by: 1.0)) { context in
                    let elapsed = max(0, Int(context.date.timeIntervalSince(startTime)))
                    workoutInProgressCard(elapsed: elapsed)
                }
            } else if let duration = day.durationSeconds {
                workoutCompletedCard(duration: duration)
            } else {
                workoutNotStartedCard
            }
        }
    }

    private var workoutNotStartedCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "timer")
                    .font(.title2)
                    .foregroundStyle(themeManager.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Timer")
                        .font(.headline)
                    Text("Track total time spent on this workout")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                startWorkout()
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
        }
        .padding(.vertical, 4)
    }

    private func workoutInProgressCard(elapsed: Int) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(themeManager.accentColor)
                        .frame(width: 8, height: 8)
                    Text("Workout In Progress")
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.accentColor)
                }
                Spacer()
                Text("\(completedCount) / \(day.exercises.count) done")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(formatTimerDigits(elapsed))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    finishWorkoutManually()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                .tint(themeManager.completedColor)
            }

            Text("Timer stops automatically when all exercises are completed.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }

    private func workoutCompletedCard(duration: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(themeManager.completedColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Workout Completed!")
                        .font(.headline)
                    Text("Total time: \(formatDurationText(duration))")
                        .font(.subheadline.bold())
                        .foregroundStyle(themeManager.completedColor)
                }

                Spacer()

                Button {
                    resetWorkoutTimer()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.bordered)
                .tint(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Workout Timer Helpers

    private func startWorkout() {
        if completedCount == day.exercises.count && !day.exercises.isEmpty {
            for exercise in day.exercises {
                exercise.isCompleted = false
                exercise.completedSets = 0
            }
        }
        day.durationSeconds = nil
        day.workoutStartTime = Date()
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func finishWorkoutManually() {
        guard let startTime = day.workoutStartTime else { return }
        let elapsed = max(1, Int(Date().timeIntervalSince(startTime)))
        day.durationSeconds = elapsed
        day.workoutStartTime = nil
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func resetWorkoutTimer() {
        day.workoutStartTime = nil
        day.durationSeconds = nil
    }

    private func checkAutoFinish(newCount: Int) {
        if let startTime = day.workoutStartTime,
           newCount == day.exercises.count,
           !day.exercises.isEmpty {
            let elapsed = max(1, Int(Date().timeIntervalSince(startTime)))
            day.durationSeconds = elapsed
            day.workoutStartTime = nil
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
        }
    }

    private func formatTimerDigits(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return String(format: "%02d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%02d:%02d", m, s)
        }
    }

    private func formatDurationText(_ totalSeconds: Int) -> String {
        let h = totalSeconds / 3600
        let m = (totalSeconds % 3600) / 60
        let s = totalSeconds % 60
        if h > 0 {
            return "\(h)h \(m)m \(s)s"
        } else if m > 0 {
            return s > 0 ? "\(m)m \(s)s" : "\(m) min"
        } else {
            return "\(s) sec"
        }
    }

    var exercisesSectionHeader: some View {
        HStack {
            Text("Exercises")
            Spacer()
            if !day.exercises.isEmpty {
                Text("\(completedCount) / \(day.exercises.count) done")
                    .font(.caption)
                    .foregroundStyle(completedCount == day.exercises.count ? themeManager.completedColor : .secondary)
                    .fontWeight(completedCount == day.exercises.count ? .semibold : .regular)
            }
        }
    }

    func routineGroupHeader(name: String, exercises: [WorkoutExercise]) -> some View {
        let done = exercises.filter(\.isCompleted).count
        return HStack {
            Label(name.isEmpty ? "Exercises" : name, systemImage: "list.bullet.clipboard.fill")
                .foregroundStyle(themeManager.accentColor)
            Spacer()
            if !exercises.isEmpty {
                Text("\(done) / \(exercises.count) done")
                    .font(.caption)
                    .foregroundStyle(done == exercises.count ? themeManager.completedColor : .secondary)
                    .fontWeight(done == exercises.count ? .semibold : .regular)
            }
        }
    }

    private func deleteExercises(in list: [WorkoutExercise], at offsets: IndexSet) {
        for index in offsets {
            let exercise = list[index]
            modelContext.delete(exercise)
        }
    }
}

// MARK: - Workout Exercise Row

struct WorkoutExerciseRow: View {
    @Environment(ThemeManager.self) private var themeManager

    let exercise: WorkoutExercise
    var onEdit: (WorkoutExercise) -> Void
    var onStartTimer: (WorkoutExercise) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Completion toggle
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    exercise.isCompleted.toggle()
                    if exercise.isCompleted {
                        exercise.completedSets = exercise.sets
                    } else {
                        exercise.completedSets = 0
                    }
                }
            } label: {
                Image(
                    systemName: exercise.isCompleted
                        ? "checkmark.circle.fill"
                        : "circle"
                )
                .font(.title2)
                .foregroundStyle(exercise.isCompleted ? themeManager.completedColor : Color.secondary)
            }
            .buttonStyle(.plain)

            // Exercise details (tappable to start rest timer)
            VStack(alignment: .leading, spacing: 5) {
                Text(exercise.name)
                    .font(.headline)
                    .strikethrough(exercise.isCompleted, color: .secondary)
                    .foregroundStyle(exercise.isCompleted ? .secondary : .primary)
                    .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)

                HStack(spacing: 16) {
                    statBadge(icon: "repeat", label: "\(exercise.sets)x")
                    if !isLongReps {
                        statBadge(icon: "number", label: exercise.reps)
                    }
                    statBadge(icon: "timer", label: restLabel)
                    if !exercise.currentPausePoints.isEmpty {
                        statBadge(icon: "pause.circle.fill", label: "\(exercise.currentPausePoints.count)x")
                    }
                }
                .opacity(exercise.isCompleted ? 0.5 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)

                if isLongReps {
                    statBadge(icon: "number", label: exercise.reps)
                        .opacity(exercise.isCompleted ? 0.5 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)
                }

                if !exercise.currentNotes.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "note.text")
                        Text(exercise.currentNotes)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .opacity(exercise.isCompleted ? 0.5 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: exercise.isCompleted)
                }

                if exercise.currentCompletedSets > 0 && !exercise.isCompleted {
                    Text("Sets completed: \(exercise.currentCompletedSets) / \(exercise.sets)")
                        .font(.caption2.bold())
                        .foregroundStyle(themeManager.accentColor)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                onStartTimer(exercise)
            }

            Spacer(minLength: 4)

            HStack(spacing: 10) {
                // Play button for rest timer
                Button {
                    onStartTimer(exercise)
                } label: {
                    let isCurrentActive = RestTimerManager.shared.activeExerciseId == exercise.id && RestTimerManager.shared.isTimerRunning
                    let iconName = isCurrentActive
                        ? (RestTimerManager.shared.isTimerPaused ? "pause.circle.fill" : "timer.circle.fill")
                        : "play.circle.fill"
                    let iconColor = isCurrentActive
                        ? (RestTimerManager.shared.isTimerPaused ? themeManager.secondaryColor : themeManager.accentColor)
                        : themeManager.accentColor

                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                }
                .buttonStyle(.plain)

                // Edit button
                Button {
                    onEdit(exercise)
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title2)
                        .foregroundStyle(Color.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 4)
    }

    private var isLongReps: Bool {
        exercise.reps.trimmingCharacters(in: .whitespaces).count > 6
    }

    func statBadge(icon: String, label: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(label)
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    private var restLabel: String {
        if exercise.restSeconds >= 60 {
            let mins = exercise.restSeconds / 60
            let secs = exercise.restSeconds % 60
            return secs == 0 ? "\(mins)m" : "\(mins)m\(secs)"
        }
        return "\(exercise.restSeconds)s"
    }
}
