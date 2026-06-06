import SwiftUI
import SwiftData

struct RoutineListView: View {
    @Query(sort: \Routine.createdAt, order: .reverse) private var routines: [Routine]
    @Environment(\.modelContext) private var modelContext

    @State private var showCreateRoutine = false
    @State private var routineToEdit: Routine?

    var body: some View {
        NavigationStack {
            Group {
                if routines.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(routines) { routine in
                            Button {
                                routineToEdit = routine
                            } label: {
                                RoutineRow(routine: routine)
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: deleteRoutines)
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                if !routines.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showCreateRoutine = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCreateRoutine) {
                CreateRoutineView()
            }
            .sheet(item: $routineToEdit) { routine in
                CreateRoutineView(routine: routine)
            }
        }
    }

    var emptyState: some View {
        VStack(spacing: 28) {
            Spacer()
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            VStack(spacing: 8) {
                Text("No routines yet")
                    .font(.title2.bold())
                Text("Build your first exercise routine.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Button {
                showCreateRoutine = true
            } label: {
                Label("Create Routine", systemImage: "plus.circle.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            Spacer()
        }
        .padding()
    }

    func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(routines[index])
        }
    }
}

// MARK: - Routine Row

struct RoutineRow: View {
    let routine: Routine

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.accentColor.opacity(0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: "dumbbell.fill")
                    .foregroundStyle(Color.accentColor)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(routine.name)
                    .font(.headline)
                Text(
                    "\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")"
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.footnote.bold())
        }
        .padding(.vertical, 6)
    }
}
