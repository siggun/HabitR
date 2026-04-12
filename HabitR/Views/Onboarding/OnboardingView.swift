import SwiftUI

// 3-screen onboarding flow shown only on first launch
// Screen 1: Welcome, Screen 2: Create first habit, Screen 3: Set reminder time
struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @Environment(\.modelContext) private var modelContext

    @State private var currentPage = 0
    @State private var habitName = ""
    @State private var habitEmoji = "dumbbell.fill"
    @State private var reminderHour = 20 // 8 PM default
    @State private var reminderMinute = 0
    @State private var reminderEnabled = true

    var body: some View {
        VStack {
            // Page content
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                createHabitPage.tag(1)
                reminderPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .animation(.easeInOut, value: currentPage)

            // Bottom button
            bottomButton
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
        }
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Welcome to HabitR")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Build lasting habits with streaks,\nprogress tracking, and daily reminders.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
    }

    // MARK: - Page 2: Create First Habit

    private var createHabitPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: habitEmoji)
                .font(.system(size: 50))
                .foregroundStyle(Color.accentColor)

            Text("Create Your First Habit")
                .font(.title2)
                .fontWeight(.bold)

            TextField("e.g., Drink water, Exercise, Read", text: $habitName)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal, 40)

            // Quick icon picker — SF Symbols for common habits
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(["dumbbell.fill", "figure.run", "book.fill", "drop.fill",
                             "figure.yoga", "bed.double.fill", "leaf.fill", "pencil.line"], id: \.self) { icon in
                        Button {
                            habitEmoji = icon
                        } label: {
                            Image(systemName: icon)
                                .font(.title3)
                                .foregroundStyle(habitEmoji == icon ? Color.accentColor : .primary)
                                .padding(10)
                                .background(habitEmoji == icon ? Color.accentColor.opacity(0.15) : Color(.systemGray6))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding(.horizontal, 40)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Page 3: Reminder

    private var reminderPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bell.badge.fill")
                .font(.system(size: 60))
                .foregroundStyle(Color.accentColor)

            Text("Set a Daily Reminder")
                .font(.title2)
                .fontWeight(.bold)

            Text("We'll remind you once a day\nto check off your habits.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Toggle("Daily Reminder", isOn: $reminderEnabled)
                .padding(.horizontal, 40)

            if reminderEnabled {
                // DatePicker in .hourAndMinute mode for time selection
                DatePicker(
                    "Reminder Time",
                    selection: reminderTimeBinding,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(height: 120)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            handleButtonTap()
        } label: {
            Text(currentPage == 2 ? "Get Started" : "Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(buttonDisabled ? Color.gray : Color.accentColor)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(buttonDisabled)
    }

    private var buttonDisabled: Bool {
        currentPage == 1 && habitName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func handleButtonTap() {
        if currentPage < 2 {
            withAnimation { currentPage += 1 }
        } else {
            finishOnboarding()
        }
    }

    private func finishOnboarding() {
        // Create the first habit if a name was entered
        let trimmed = habitName.trimmingCharacters(in: .whitespaces)
        if !trimmed.isEmpty {
            let habit = Habit(name: trimmed, emoji: habitEmoji)
            modelContext.insert(habit)
            try? modelContext.save()
        }

        // Schedule notification if enabled
        if reminderEnabled {
            Task {
                let granted = await NotificationService.shared.requestPermission()
                if granted {
                    NotificationService.shared.scheduleDailyReminder(
                        hour: reminderHour,
                        minute: reminderMinute
                    )
                }
            }
        }

        // Save reminder time preference
        UserDefaults.standard.set(reminderHour, forKey: "reminderHour")
        UserDefaults.standard.set(reminderMinute, forKey: "reminderMinute")
        UserDefaults.standard.set(reminderEnabled, forKey: "reminderEnabled")

        hasCompletedOnboarding = true
    }

    // MARK: - Helpers

    /// Binding that converts hour/minute state into a Date for DatePicker
    private var reminderTimeBinding: Binding<Date> {
        Binding<Date>(
            get: {
                var components = DateComponents()
                components.hour = reminderHour
                components.minute = reminderMinute
                return Calendar.current.date(from: components) ?? Date()
            },
            set: { newDate in
                let components = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                reminderHour = components.hour ?? 20
                reminderMinute = components.minute ?? 0
            }
        )
    }
}
