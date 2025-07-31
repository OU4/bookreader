//
//  ReadingGoalManager.swift
//  BookReader
//
//  Manages reading goals, achievements, and daily progress
//

import Foundation
import UserNotifications

class ReadingGoalManager {
    static let shared = ReadingGoalManager()
    private init() {}
    
    // MARK: - Goal Management
    func checkDailyGoalProgress() -> GoalProgress {
        let goal = ReadingSessionTracker.shared.getReadingGoal()
        let todayProgress = getTodayProgress(for: goal)
        
        return GoalProgress(
            goal: goal,
            currentValue: todayProgress.current,
            percentage: todayProgress.percentage,
            isCompleted: todayProgress.percentage >= 100,
            streak: ReadingSessionTracker.shared.getCurrentStreak()
        )
    }
    
    private func getTodayProgress(for goal: ReadingGoal) -> (current: Double, percentage: Double) {
        let tracker = ReadingSessionTracker.shared
        
        switch goal.type {
        case .time:
            let todayTime = tracker.getTodayReadingTime()
            let current = todayTime / 60.0 // Convert to minutes
            let percentage = (current / goal.target) * 100
            return (current, percentage)
            
        case .pages:
            // This would need to be implemented based on actual page tracking
            return (0, 0)
            
        case .books:
            // This would need to be implemented based on book completion tracking
            return (0, 0)
        }
    }
    
    // MARK: - Achievement System
    func checkForAchievements() -> [Achievement] {
        var achievements: [Achievement] = []
        
        let progress = checkDailyGoalProgress()
        let streak = ReadingSessionTracker.shared.getCurrentStreak()
        
        // Daily goal achievements
        if progress.isCompleted && !wasGoalCompletedToday() {
            achievements.append(Achievement(
                type: .dailyGoalCompleted,
                title: "Daily Goal Achieved!",
                description: "You've reached your daily reading goal",
                icon: "🎯"
            ))
            markGoalCompletedToday()
        }
        
        // Streak achievements
        if streak > 0 && streak % 7 == 0 && !wasStreakCelebratedThisWeek() {
            achievements.append(Achievement(
                type: .weeklyStreak,
                title: "Weekly Streak!",
                description: "You've read for \\(streak) days in a row",
                icon: "🔥"
            ))
            markStreakCelebratedThisWeek()
        }
        
        // Milestones
        if streak == 30 {
            achievements.append(Achievement(
                type: .monthlyStreak,
                title: "Reading Master!",
                description: "30 days of consistent reading",
                icon: "👑"
            ))
        }
        
        return achievements
    }
    
    // MARK: - Notifications
    func scheduleReadingReminder() {
        let content = UNMutableNotificationContent()
        content.title = "Time to Read"
        content.body = "Continue your reading journey and maintain your streak!"
        content.sound = .default
        
        // Schedule for 7 PM daily
        var dateComponents = DateComponents()
        dateComponents.hour = 19
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        let request = UNNotificationRequest(
            identifier: "dailyReadingReminder",
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    func sendGoalCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Goal Achieved! 🎉"
        content.body = "You've completed your daily reading goal. Great job!"
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "goalCompleted",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        
        UNUserNotificationCenter.current().add(request)
    }
    
    // MARK: - Private Helpers
    private func wasGoalCompletedToday() -> Bool {
        let lastCompletionDate = UserDefaults.standard.object(forKey: "lastGoalCompletionDate") as? Date
        return Calendar.current.isDateInToday(lastCompletionDate ?? Date.distantPast)
    }
    
    private func markGoalCompletedToday() {
        UserDefaults.standard.set(Date(), forKey: "lastGoalCompletionDate")
    }
    
    private func wasStreakCelebratedThisWeek() -> Bool {
        let lastCelebrationDate = UserDefaults.standard.object(forKey: "lastStreakCelebrationDate") as? Date
        guard let lastDate = lastCelebrationDate else { return false }
        
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        return lastDate > weekAgo
    }
    
    private func markStreakCelebratedThisWeek() {
        UserDefaults.standard.set(Date(), forKey: "lastStreakCelebrationDate")
    }
}

// MARK: - Models
struct GoalProgress {
    let goal: ReadingGoal
    let currentValue: Double
    let percentage: Double
    let isCompleted: Bool
    let streak: Int
    
    var displayText: String {
        switch goal.type {
        case .time:
            let minutes = Int(currentValue)
            let targetMinutes = Int(goal.target)
            return "\\(minutes)/\\(targetMinutes) min"
        case .pages:
            return "\\(Int(currentValue))/\\(Int(goal.target)) pages"
        case .books:
            return "\\(Int(currentValue))/\\(Int(goal.target)) books"
        }
    }
}

struct Achievement {
    enum AchievementType {
        case dailyGoalCompleted
        case weeklyStreak
        case monthlyStreak
        case readingSpeedImproved
        case bookCompleted
    }
    
    let type: AchievementType
    let title: String
    let description: String
    let icon: String
    let dateEarned: Date
    
    init(type: AchievementType, title: String, description: String, icon: String) {
        self.type = type
        self.title = title
        self.description = description
        self.icon = icon
        self.dateEarned = Date()
    }
}