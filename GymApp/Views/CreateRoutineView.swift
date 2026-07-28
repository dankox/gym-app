import SwiftUI
import SwiftData

// MARK: - Draft Model

struct ExerciseDraft: Identifiable {
    var id = UUID()
    var name: String = ""
    var sets: Int = 3
    var reps: String = "10"
    var restSeconds: Int = 60
    var pausePoints: [Int] = []
}

// MARK: - Create / Edit Routine View

struct CreateRoutineView: View {
    @Environment(ThemeManager.self) private var themeManager
    var routine: Routine?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var routineName = ""
    @State private var drafts: [ExerciseDraft] = []
    @State private var showAddExercise = false
    @State private var draftToEdit: ExerciseDraft?

    private var isEditing: Bool { routine != nil }

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine Name") {
                    TextField("e.g. Push Day, Upper Body…", text: $routineName)
                        .textInputAutocapitalization(.words)
                }

                Section {
                    ForEach(drafts) { draft in
                        ExerciseDraftRow(draft: draft)
                            .contentShape(Rectangle())
                            .onTapGesture { draftToEdit = draft }
                    }
                    .onMove(perform: moveDrafts)
                    .onDelete(perform: deleteDrafts)

                    Button {
                        showAddExercise = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus.circle.fill")
                            .foregroundStyle(themeManager.accentColor)
                    }
                } header: {
                    Text("Exercises\(drafts.isEmpty ? "" : " (\(drafts.count))")")
                } footer: {
                    if !drafts.isEmpty {
                        Text("Tap an exercise to edit. Hold and drag to reorder.")
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Routine" : "New Routine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(routineName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                if !drafts.isEmpty {
                    ToolbarItem(placement: .bottomBar) {
                        EditButton()
                    }
                }
            }
            .sheet(isPresented: $showAddExercise) {
                AddExerciseView { newDraft in
                    var d = newDraft
                    d.id = UUID()
                    drafts.append(d)
                }
            }
            .sheet(item: $draftToEdit) { draft in
                AddExerciseView(draft: draft) { updated in
                    if let idx = drafts.firstIndex(where: { $0.id == draft.id }) {
                        drafts[idx] = updated
                    }
                }
            }
            .onAppear(perform: loadExistingRoutine)
        }
    }

    // MARK: - Load existing routine on appear

    func loadExistingRoutine() {
        guard let routine else { return }
        routineName = routine.name
        drafts = routine.exercises
            .sorted { $0.sortOrder < $1.sortOrder }
            .map { ExerciseDraft(name: $0.name, sets: $0.sets, reps: $0.reps, restSeconds: $0.restSeconds, pausePoints: $0.currentPausePoints) }
    }

    // MARK: - Save

    func save() {
        let name = routineName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }

        if let routine {
            routine.name = name
            let toDelete = Array(routine.exercises)
            toDelete.forEach { modelContext.delete($0) }
            routine.exercises.removeAll()
            for (index, draft) in drafts.enumerated() {
                let template = ExerciseTemplate(
                    name: draft.name, sets: draft.sets, reps: draft.reps,
                    restSeconds: draft.restSeconds, sortOrder: index,
                    pausePoints: draft.pausePoints
                )
                routine.exercises.append(template)
            }
        } else {
            let newRoutine = Routine(name: name)
            modelContext.insert(newRoutine)
            for (index, draft) in drafts.enumerated() {
                let template = ExerciseTemplate(
                    name: draft.name, sets: draft.sets, reps: draft.reps,
                    restSeconds: draft.restSeconds, sortOrder: index,
                    pausePoints: draft.pausePoints
                )
                newRoutine.exercises.append(template)
            }
        }
        dismiss()
    }

    // MARK: - List Operations

    func moveDrafts(from source: IndexSet, to destination: Int) {
        drafts.move(fromOffsets: source, toOffset: destination)
    }

    func deleteDrafts(at offsets: IndexSet) {
        drafts.remove(atOffsets: offsets)
    }
}

// MARK: - Exercise Draft Row

struct ExerciseDraftRow: View {
    let draft: ExerciseDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(draft.name.isEmpty ? "Unnamed Exercise" : draft.name)
                .font(.headline)
                .foregroundStyle(draft.name.isEmpty ? .secondary : .primary)
            HStack(spacing: 16) {
                statLabel(icon: "repeat", text: "\(draft.sets)x")
                statLabel(icon: "number", text: draft.reps)
                statLabel(icon: "timer", text: restLabel(for: draft.restSeconds))
                if !draft.pausePoints.isEmpty {
                    statLabel(icon: "pause.circle.fill", text: "\(draft.pausePoints.count)x")
                }
            }
        }
        .padding(.vertical, 4)
    }

    func statLabel(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(.caption)
        .foregroundStyle(.secondary)
    }

    func restLabel(for seconds: Int) -> String {
        if seconds >= 60 {
            let m = seconds / 60
            let s = seconds % 60
            return s == 0 ? "\(m)m" : "\(m)m\(s)s"
        }
        return "\(seconds)s"
    }
}
