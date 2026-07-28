import SwiftUI
import SwiftData

struct CalendarView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.modelContext) private var modelContext
    @Query private var workoutDays: [WorkoutDay]

    @State private var selectedDate = Date()
    @State private var currentMonth = Date()
    @State private var showDayDetail = false
    @State private var showDeleteConfirmation = false

    private let calendar = Calendar.current

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                monthNavigationHeader
                weekdayLabels
                calendarGrid
                    .padding(.bottom, 8)
                Divider()
                selectedDayPanel
                Spacer(minLength: 0)
            }
            .navigationTitle("Gym Tracker")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Today") {
                        selectedDate = Date()
                        currentMonth = Date()
                    }
                    .disabled(calendar.isDate(currentMonth, equalTo: Date(), toGranularity: .month)
                              && calendar.isDateInToday(selectedDate))
                }
            }
            .sheet(isPresented: $showDayDetail) {
                DayDetailView(date: selectedDate)
            }
            .confirmationDialog(
                "Remove Logged Workout",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Remove", role: .destructive) {
                    deleteWorkoutForSelectedDate()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to remove the logged workout for \(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))?")
            }
        }
    }

    // MARK: - Month Navigation Header

    var monthNavigationHeader: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
            Spacer()
            Text(currentMonth.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .animation(.none, value: currentMonth)
            Spacer()
            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title2)
                    .foregroundStyle(.primary)
                    .frame(width: 44, height: 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Weekday Labels

    var weekdayLabels: some View {
        HStack(spacing: 0) {
            ForEach(localizedWeekdaySymbols, id: \.self) { symbol in
                Text(symbol)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 4)
    }

    // MARK: - Calendar Grid

    var calendarGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7),
            spacing: 4
        ) {
            ForEach(0..<leadingEmptyCells, id: \.self) { _ in
                Color.clear.frame(height: 48)
            }
            ForEach(daysInCurrentMonth, id: \.self) { date in
                DayCell(
                    date: date,
                    isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                    isToday: calendar.isDateInToday(date),
                    hasWorkout: workoutDayFor(date) != nil
                )
                .onTapGesture {
                    selectedDate = date
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Selected Day Panel

    var selectedDayPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let day = workoutDayFor(selectedDate) {
                workoutDaySummary(day)
            } else {
                emptyDayPrompt
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.easeInOut(duration: 0.2), value: selectedDate)
    }

    func workoutDaySummary(_ day: WorkoutDay) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                        .font(.headline)
                    if !day.routineName.isEmpty {
                        Label(day.routineName, systemImage: "list.bullet.clipboard")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("\(day.exercises.count) exercise\(day.exercises.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let duration = day.durationSeconds {
                        Label("Duration: \(formatDurationText(duration))", systemImage: "clock.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.completedColor)
                    } else if day.workoutStartTime != nil {
                        Label("Workout in progress…", systemImage: "timer")
                            .font(.subheadline.bold())
                            .foregroundStyle(themeManager.accentColor)
                    }
                }
                Spacer()
                HStack(spacing: 8) {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                    .controlSize(.regular)

                    Button("View Details") { showDayDetail = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                }
            }
        }
        .padding()
    }

    var emptyDayPrompt: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(selectedDate.formatted(.dateTime.weekday(.wide).day().month(.wide)))
                    .font(.headline)
                Text("No workout logged")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                showDayDetail = true
            } label: {
                Label("Log Workout", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
    }

    // MARK: - Helpers

    var daysInCurrentMonth: [Date] {
        guard
            let range = calendar.range(of: .day, in: .month, for: currentMonth),
            let startOfMonth = calendar.date(
                from: calendar.dateComponents([.year, .month], from: currentMonth)
            )
        else { return [] }

        return range.compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    var leadingEmptyCells: Int {
        guard let start = daysInCurrentMonth.first else { return 0 }
        let weekday = calendar.component(.weekday, from: start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    var localizedWeekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let offset = calendar.firstWeekday - 1
        return Array(symbols[offset...] + symbols[..<offset])
    }

    func workoutDayFor(_ date: Date) -> WorkoutDay? {
        workoutDays.first { calendar.isDate($0.date, inSameDayAs: date) }
    }

    func deleteWorkoutForSelectedDate() {
        if let day = workoutDayFor(selectedDate) {
            modelContext.delete(day)
        }
    }

    func previousMonth() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
        }
    }

    func nextMonth() {
        withAnimation(.easeInOut(duration: 0.25)) {
            currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
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
}

// MARK: - Day Cell

struct DayCell: View {
    @Environment(ThemeManager.self) private var themeManager

    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasWorkout: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(cellBackground)
                .frame(width: 40, height: 40)

            VStack(spacing: 2) {
                Text("\(Calendar.current.component(.day, from: date))")
                    .font(.system(.callout, design: .rounded))
                    .fontWeight(isToday ? .bold : .regular)
                    .foregroundStyle(textColor)

                Circle()
                    .fill(hasWorkout ? dotColor : Color.clear)
                    .frame(width: 5, height: 5)
            }
        }
        .frame(height: 48)
    }

    private var cellBackground: Color {
        if isSelected { return themeManager.accentColor }
        if isToday { return themeManager.accentColor.opacity(0.15) }
        return .clear
    }

    private var textColor: Color {
        if isSelected { return .white }
        if isToday { return themeManager.accentColor }
        return .primary
    }

    private var dotColor: Color {
        isSelected ? .white.opacity(0.85) : themeManager.accentColor
    }
}
