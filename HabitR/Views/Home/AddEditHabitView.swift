import SwiftUI
import SwiftData

// Sheet for creating a new habit or editing an existing one
// Includes SF Symbol icon picker, name field, frequency, and completion mode options
struct AddEditHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // If editing an existing habit, this is set; nil means creating new
    var habitToEdit: Habit?

    @State private var name: String = ""
    @State private var emoji: String = "star.fill"
    @State private var frequency: HabitFrequency = .daily
    @State private var completionMode: CompletionMode = .toggle
    @State private var dailyTarget: Int = 1
    @State private var showingIconPicker = false

    private var isEditing: Bool { habitToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Icon and name section
                Section {
                    HStack {
                        // Tappable icon button that opens the picker
                        Button { showingIconPicker.toggle() } label: {
                            Image(systemName: emoji)
                                .font(.title2)
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 50, height: 50)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        TextField("Habit name", text: $name)
                            .font(.body)
                    }

                    if showingIconPicker {
                        iconPickerGrid
                    }
                }

                // Frequency section
                Section("Frequency") {
                    Picker("Frequency", selection: $frequency) {
                        ForEach(HabitFrequency.allCases, id: \.self) { freq in
                            Text(freq.rawValue).tag(freq)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Completion mode section
                Section("Completion Mode") {
                    Picker("Mode", selection: $completionMode) {
                        Text("Toggle (Yes/No)").tag(CompletionMode.toggle)
                        Text("Counter").tag(CompletionMode.counter)
                    }
                    .pickerStyle(.segmented)

                    if completionMode == .counter {
                        Stepper("Daily target: \(dailyTarget)", value: $dailyTarget, in: 1...100)
                    }
                }
            }
            .navigationTitle(isEditing ? "Edit Habit" : "New Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") { saveHabit() }
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear { loadExistingHabit() }
        }
    }

    // MARK: - Icon Picker

    private var iconPickerGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(HabitIcons.categories, id: \.name) { category in
                VStack(alignment: .leading, spacing: 6) {
                    Text(category.name)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 8) {
                        ForEach(category.icons, id: \.self) { icon in
                            Button {
                                emoji = icon
                                showingIconPicker = false
                            } label: {
                                Image(systemName: icon)
                                    .font(.body)
                                    .frame(width: 36, height: 36)
                                    .foregroundStyle(emoji == icon ? Color.accentColor : .primary)
                                    .background(emoji == icon ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Actions

    private func loadExistingHabit() {
        guard let habit = habitToEdit else { return }
        name = habit.name
        emoji = habit.emoji
        frequency = habit.frequency
        completionMode = habit.completionMode
        dailyTarget = habit.dailyTarget
    }

    private func saveHabit() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }

        if let habit = habitToEdit {
            habit.name = trimmedName
            habit.emoji = emoji
            habit.frequency = frequency
            habit.completionMode = completionMode
            habit.dailyTarget = dailyTarget
        } else {
            let habit = Habit(
                name: trimmedName,
                emoji: emoji,
                frequency: frequency,
                completionMode: completionMode,
                dailyTarget: dailyTarget
            )
            modelContext.insert(habit)
        }

        try? modelContext.save()
        dismiss()
    }
}

// MARK: - Icon Data

/// Curated SF Symbols organized by habit category
struct HabitIcons {
    struct Category {
        let name: String
        let icons: [String]
    }

    static let categories: [Category] = [
        Category(name: "Fitness", icons: [
            "figure.run", "figure.walk", "dumbbell.fill",
            "figure.yoga", "figure.hiking", "bicycle",
        ]),
        Category(name: "Health", icons: [
            "heart.fill", "drop.fill", "pill.fill",
            "bed.double.fill", "moon.zzz.fill", "brain.head.profile",
        ]),
        Category(name: "Productivity", icons: [
            "book.fill", "pencil.line", "doc.text.fill",
            "laptopcomputer", "clock.fill", "target",
        ]),
        Category(name: "Lifestyle", icons: [
            "cup.and.saucer.fill", "leaf.fill", "fork.knife",
            "cart.fill", "music.note", "paintbrush.fill",
        ]),
        Category(name: "Wellness", icons: [
            "figure.mind.and.body", "sparkles", "sun.max.fill",
            "moon.fill", "eye.fill", "hands.clap.fill",
        ]),
        Category(name: "General", icons: [
            "star.fill", "checkmark.seal.fill", "flag.fill",
            "bolt.fill", "flame.fill", "house.fill",
        ]),
    ]

    /// Flat list of all icons for quick lookup
    static let all: [String] = categories.flatMap(\.icons)
}
