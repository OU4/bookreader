//
//  ReadingStatsViewController.swift
//  BookReader
//
//  Detailed reading statistics and insights
//

import UIKit
import Charts

class ReadingStatsViewController: UIViewController {
    
    // MARK: - UI Components
    private lazy var scrollView: UIScrollView = {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()
    
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var todayStatsView: TodayStatsView = {
        let view = TodayStatsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var weeklyChartView: UIView = {
        let view = UIView()
        view.backgroundColor = .secondarySystemBackground
        view.layer.cornerRadius = 12
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var streakView: StreakView = {
        let view = StreakView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var goalsView: GoalsView = {
        let view = GoalsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    private lazy var insightsView: InsightsView = {
        let view = InsightsView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupNavigationBar()
        loadStats()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshStats()
    }
    
    // MARK: - Setup
    private func setupUI() {
        view.backgroundColor = .systemBackground
        
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)
        
        contentView.addSubview(todayStatsView)
        contentView.addSubview(weeklyChartView)
        contentView.addSubview(streakView)
        contentView.addSubview(goalsView)
        contentView.addSubview(insightsView)
        
        NSLayoutConstraint.activate([
            // Scroll view
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            
            // Content view
            contentView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            
            // Today stats
            todayStatsView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 20),
            todayStatsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            todayStatsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            todayStatsView.heightAnchor.constraint(equalToConstant: 120),
            
            // Weekly chart
            weeklyChartView.topAnchor.constraint(equalTo: todayStatsView.bottomAnchor, constant: 20),
            weeklyChartView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            weeklyChartView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            weeklyChartView.heightAnchor.constraint(equalToConstant: 200),
            
            // Streak view
            streakView.topAnchor.constraint(equalTo: weeklyChartView.bottomAnchor, constant: 20),
            streakView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            streakView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            streakView.heightAnchor.constraint(equalToConstant: 100),
            
            // Goals view
            goalsView.topAnchor.constraint(equalTo: streakView.bottomAnchor, constant: 20),
            goalsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            goalsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            goalsView.heightAnchor.constraint(equalToConstant: 150),
            
            // Insights view
            insightsView.topAnchor.constraint(equalTo: goalsView.bottomAnchor, constant: 20),
            insightsView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            insightsView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            insightsView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -20)
        ])
    }
    
    private func setupNavigationBar() {
        title = "Reading Stats"
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "gear"),
            style: .plain,
            target: self,
            action: #selector(showSettings)
        )
        
        // Add close button if presented modally
        if presentingViewController != nil {
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .done,
                target: self,
                action: #selector(dismissView)
            )
        }
    }
    
    @objc private func dismissView() {
        dismiss(animated: true)
    }
    
    // MARK: - Data Loading
    private func loadStats() {
        refreshStats()
    }
    
    private func refreshStats() {
        let tracker = ReadingSessionTracker.shared
        let goalManager = ReadingGoalManager.shared
        
        // Update today stats
        let todayTime = tracker.getTodayReadingTime()
        let goalProgress = goalManager.checkDailyGoalProgress()
        let currentStreak = tracker.getCurrentStreak()
        
        print("📊 Stats Debug - Today Time: \(todayTime)s, Goal Progress: \(goalProgress.percentage)%, Streak: \(currentStreak)")
        
        todayStatsView.updateStats(
            readingTime: todayTime,
            goalProgress: goalProgress,
            streak: currentStreak
        )
        
        // Update streak view
        streakView.updateStreak(
            current: tracker.getCurrentStreak(),
            longest: UserDefaults.standard.integer(forKey: "longestReadingStreak")
        )
        
        // Update goals view
        goalsView.updateGoal(goalProgress)
        
        // Update insights
        updateInsights()
    }
    
    private func updateInsights() {
        let tracker = ReadingSessionTracker.shared
        let weeklyTime = tracker.getWeeklyReadingTime()
        let todayTime = tracker.getTodayReadingTime()
        let averageDaily = weeklyTime / 7
        let currentStreak = tracker.getCurrentStreak()
        
        var insights: [String] = []
        
        // Weekly summary
        insights.append("📊 This week: \\(formatTime(weeklyTime))")
        
        // Daily average comparison
        if averageDaily > 0 {
            insights.append("⏱️ Daily average: \\(formatTime(averageDaily))")
            
            if todayTime > averageDaily {
                let improvement = ((todayTime - averageDaily) / averageDaily) * 100
                insights.append("📈 Today you're \\(Int(improvement))% above your average!")
            } else if todayTime < averageDaily && todayTime > 0 {
                insights.append("💪 Keep going! You can still reach your daily average")
            }
        }
        
        // Streak insights
        if currentStreak >= 7 {
            insights.append("🔥 Amazing! \\(currentStreak) day streak - you're building a great habit")
        } else if currentStreak >= 3 {
            insights.append("🌟 Great momentum with your \\(currentStreak) day streak!")
        } else if currentStreak >= 1 {
            insights.append("✨ You're on a \\(currentStreak) day streak - keep it up!")
        }
        
        // Goal insights
        insights.append("🎯 \\(getGoalInsight())")
        
        // Reading speed insights
        if let readingSpeedInsight = getReadingSpeedInsight() {
            insights.append(readingSpeedInsight)
        }
        
        // Encouragement based on performance
        insights.append("💡 \\(getEncouragementMessage())")
        
        insightsView.updateInsights(insights)
    }
    
    private func formatTime(_ timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval / 60)
        let hours = minutes / 60
        let remainingMinutes = minutes % 60
        
        if hours > 0 {
            return "\\(hours)h \\(remainingMinutes)m"
        } else {
            return "\\(minutes)m"
        }
    }
    
    private func getGoalInsight() -> String {
        let progress = ReadingGoalManager.shared.checkDailyGoalProgress()
        
        if progress.isCompleted {
            return "Great job! You've completed your daily goal"
        } else {
            let remaining = progress.goal.target - progress.currentValue
            return "\\(Int(remaining)) minutes left to reach your goal"
        }
    }
    
    private func getReadingSpeedInsight() -> String? {
        // This would need to access book reading stats to get average reading speed
        // For now, return a motivational insight about reading speed
        return "⚡ Focus on comprehension over speed - quality reading matters most"
    }
    
    private func getEncouragementMessage() -> String {
        let goalProgress = ReadingGoalManager.shared.checkDailyGoalProgress()
        let streak = ReadingSessionTracker.shared.getCurrentStreak()
        
        if goalProgress.isCompleted {
            return "Excellent! You've achieved your daily goal. Consider reading a bit more or explore a new book!"
        } else if goalProgress.percentage >= 75 {
            return "You're so close to your goal! Just a little more to complete today's target"
        } else if goalProgress.percentage >= 50 {
            return "Great progress! You're halfway to your goal. Keep the momentum going"
        } else if goalProgress.percentage >= 25 {
            return "Good start! Every page counts toward building your reading habit"
        } else if streak > 0 {
            return "You've got this! Your \\(streak)-day streak shows you're committed to reading"
        } else {
            return "Today is perfect to start reading! Even 10 minutes can make a difference"
        }
    }
    
    // MARK: - Actions
    @objc private func showSettings() {
        let settingsVC = GoalSettingsViewController()
        let navController = UINavigationController(rootViewController: settingsVC)
        present(navController, animated: true)
    }
}

// MARK: - Today Stats View
class TodayStatsView: UIView {
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = "Today"
        label.font = UIFont.boldSystemFont(ofSize: 20)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let statsStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.distribution = .fillEqually
        stackView.spacing = 16
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()
    
    private let readingTimeView = StatItemView()
    private let goalProgressView = StatItemView()
    private let streakView = StatItemView()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        
        addSubview(titleLabel)
        addSubview(statsStackView)
        
        statsStackView.addArrangedSubview(readingTimeView)
        statsStackView.addArrangedSubview(goalProgressView)
        statsStackView.addArrangedSubview(streakView)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: 16),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            
            statsStackView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 16),
            statsStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            statsStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            statsStackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -16)
        ])
    }
    
    func updateStats(readingTime: TimeInterval, goalProgress: GoalProgress, streak: Int) {
        let minutes = Int(readingTime / 60)
        readingTimeView.configure(
            value: "\(minutes)m",
            title: "Reading Time",
            color: .systemBlue
        )
        
        goalProgressView.configure(
            value: "\(Int(goalProgress.percentage))%",
            title: "Goal Progress",
            color: goalProgress.isCompleted ? .systemGreen : .systemOrange
        )
        
        streakView.configure(
            value: "\(streak)",
            title: "Day Streak",
            color: .systemPurple
        )
    }
}

// MARK: - Stat Item View
class StatItemView: UIView {
    
    private let valueLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.boldSystemFont(ofSize: 24)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 12, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        addSubview(valueLabel)
        addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            valueLabel.topAnchor.constraint(equalTo: topAnchor),
            valueLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            valueLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            
            titleLabel.topAnchor.constraint(equalTo: valueLabel.bottomAnchor, constant: 4),
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
    
    func configure(value: String, title: String, color: UIColor) {
        valueLabel.text = value
        valueLabel.textColor = color
        titleLabel.text = title
    }
}

// MARK: - Other Views (Simplified)
class StreakView: UIView {
    private let streakLabel = UILabel()
    private let longestLabel = UILabel()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        // Setup UI elements...
    }
    
    func updateStreak(current: Int, longest: Int) {
        // Update streak display...
    }
}

class GoalsView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        // Setup UI elements...
    }
    
    func updateGoal(_ progress: GoalProgress) {
        // Update goal display...
    }
}

class InsightsView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .secondarySystemBackground
        layer.cornerRadius = 12
        // Setup UI elements...
    }
    
    func updateInsights(_ insights: [String]) {
        // Update insights display...
    }
}

class GoalSettingsViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Goal Settings"
        view.backgroundColor = .systemBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .cancel,
            target: self,
            action: #selector(dismissViewController)
        )
    }
    
    @objc private func dismissViewController() {
        dismiss(animated: true)
    }
}