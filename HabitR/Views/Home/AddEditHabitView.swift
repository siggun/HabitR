import SwiftUI
import SwiftData

// Sheet for creating a new habit or editing an existing one
// Includes emoji picker, name field, frequency, and completion mode options
struct AddEditHabitView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    // If editing an existing habit, this is set; nil means creating new
    var habitToEdit: Habit?

    @State private var name: String = ""
    @State private var emoji: String = "⭐️"
    @State private var frequency: HabitFrequency = .daily
    @State private var completionMode: CompletionMode = .toggle
    @State private var dailyTarget: Int = 1
    @State private var showingEmojiPicker = false

    // Common emojis for habits — organized by category
    private let emojiOptions = [
        "💪", "🏃", "🧘", "📖", "💧", "🥗", "😴", "🧠",
        "✍️", "🎵", "🎨", "📱", "🚶", "🏋️", "🧹", "💊",
        "🍎", "☀️", "🌙", "⭐️", "✅", "🎯", "🔥", "💡",
        "🙏", "😊", "🌿", "🐕", "📝", "💰", "🎸", "🏊"
    ]

    private var isEditing: Bool { habitToEdit != nil }

    var body: some View {
        NavigationStack {
            Form {
                // Emoji and name section
                Section {
                    HStack {
                        // Tappable emoji button that opens the picker
                        Button { showingEmojiPicker.toggle() } label: {
                            Text(emoji)
                                .font(.largeTitle)
                                .frame(width: 50, height: 50)
                                .background(Color(.systemGray6))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)

                        TextField("Habit name", text: $name)
                            .font(.body)
                    }

                    if showingEmojiPicker {
                        emojiPickerGrid
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

    // MARK: - Emoji Picker

    private var emojiPickerGrid: some View {
        // LazyVGrid creates a flexible grid layout
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: 8) {
            ForEach(emojiOptions, id: \.self) { option in
                Button {
                    emoji = option
                    showingEmojiPicker = false
                } label: {
                    Text(option)
                        .font(.title2)
                        .frame(width: 36, height: 36)
                        .background(emoji == option ? Color.accentColor.opacity(0.2) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
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
            // Update existing habit
            habit.name = trimmedName
            habit.emoji = emoji
            habit.frequency = frequency
            habit.completionMode = completionMode
            habit.dailyTarget = dailyTarget
        } else {
            // Create new habit
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
