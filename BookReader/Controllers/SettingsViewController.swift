//
//  SettingsViewController.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

protocol SettingsViewControllerDelegate: AnyObject {
    func didUpdateSettings(_ settings: ReaderSettings)
}

struct ReaderSettings {
    var fontSize: CGFloat
    var fontName: String?
    var isDarkMode: Bool
    var scrollingEnabled: Bool
    var pageMargins: CGFloat
    var lineSpacing: CGFloat
}

class SettingsViewController: UITableViewController {
    
    // MARK: - Properties
    weak var delegate: SettingsViewControllerDelegate?
    
    private var settings = ReaderSettings(
        fontSize: 18,
        fontName: "Georgia",
        isDarkMode: false,
        scrollingEnabled: true,
        pageMargins: 16,
        lineSpacing: 1.5
    )
    
    private let fonts = ["Georgia", "Helvetica", "Times New Roman", "Avenir", "Baskerville", "Palatino"]
    private let fontSizes: [CGFloat] = [14, 16, 18, 20, 22, 24, 28]
    
    // MARK: - Lifecycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadSettings()
    }
    
    // MARK: - Setup
    private func setupUI() {
        title = "Settings"
        view.backgroundColor = .systemGroupedBackground
        
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(done)
        )
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        tableView.register(SwitchCell.self, forCellReuseIdentifier: "SwitchCell")
        tableView.register(SliderCell.self, forCellReuseIdentifier: "SliderCell")
    }
    
    private func loadSettings() {
        // Load from UserDefaults
        let defaults = UserDefaults.standard
        settings.fontSize = CGFloat(defaults.float(forKey: "fontSize"))
        if settings.fontSize == 0 { settings.fontSize = 18 }
        settings.fontName = defaults.string(forKey: "fontName") ?? "Georgia"
        settings.isDarkMode = defaults.bool(forKey: "isDarkMode")
        settings.scrollingEnabled = defaults.bool(forKey: "scrollingEnabled")
        settings.pageMargins = CGFloat(defaults.float(forKey: "pageMargins"))
        if settings.pageMargins == 0 { settings.pageMargins = 16 }
        settings.lineSpacing = CGFloat(defaults.float(forKey: "lineSpacing"))
        if settings.lineSpacing == 0 { settings.lineSpacing = 1.5 }
    }
    
    private func saveSettings() {
        let defaults = UserDefaults.standard
        defaults.set(Float(settings.fontSize), forKey: "fontSize")
        defaults.set(settings.fontName, forKey: "fontName")
        defaults.set(settings.isDarkMode, forKey: "isDarkMode")
        defaults.set(settings.scrollingEnabled, forKey: "scrollingEnabled")
        defaults.set(Float(settings.pageMargins), forKey: "pageMargins")
        defaults.set(Float(settings.lineSpacing), forKey: "lineSpacing")
    }
    
    // MARK: - Actions
    @objc private func done() {
        saveSettings()
        delegate?.didUpdateSettings(settings)
        dismiss(animated: true)
    }
    
    // MARK: - Table View Data Source
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 4
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case 0: return 2 // Font settings
        case 1: return 2 // Display settings
        case 2: return 2 // Layout settings
        case 3: return 1 // About
        default: return 0
        }
    }
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0: return "Font Settings"
        case 1: return "Display"
        case 2: return "Layout"
        case 3: return "About"
        default: return nil
        }
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch indexPath.section {
        case 0: // Font settings
            switch indexPath.row {
            case 0: // Font type
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.text = "Font"
                cell.detailTextLabel?.text = settings.fontName
                cell.accessoryType = .disclosureIndicator
                return cell
            case 1: // Font size
                let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
                cell.textLabel?.text = "Font Size"
                cell.detailTextLabel?.text = "\(Int(settings.fontSize))pt"
                cell.accessoryType = .disclosureIndicator
                return cell
            default:
                return UITableViewCell()
            }
            
        case 1: // Display settings
            switch indexPath.row {
            case 0: // Dark mode
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell
                cell.configure(title: "Dark Mode", isOn: settings.isDarkMode) { [weak self] isOn in
                    self?.settings.isDarkMode = isOn
                }
                return cell
            case 1: // Scrolling
                let cell = tableView.dequeueReusableCell(withIdentifier: "SwitchCell", for: indexPath) as! SwitchCell
                cell.configure(title: "Continuous Scrolling", isOn: settings.scrollingEnabled) { [weak self] isOn in
                    self?.settings.scrollingEnabled = isOn
                }
                return cell
            default:
                return UITableViewCell()
            }
            
        case 2: // Layout settings
            switch indexPath.row {
            case 0: // Margins
                let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
                cell.configure(
                    title: "Page Margins",
                    value: Float(settings.pageMargins),
                    minValue: 0,
                    maxValue: 50
                ) { [weak self] value in
                    self?.settings.pageMargins = CGFloat(value)
                }
                return cell
            case 1: // Line spacing
                let cell = tableView.dequeueReusableCell(withIdentifier: "SliderCell", for: indexPath) as! SliderCell
                cell.configure(
                    title: "Line Spacing",
                    value: Float(settings.lineSpacing),
                    minValue: 1.0,
                    maxValue: 3.0
                ) { [weak self] value in
                    self?.settings.lineSpacing = CGFloat(value)
                }
                return cell
            default:
                return UITableViewCell()
            }
            
        case 3: // About
            let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)
            cell.textLabel?.text = "Version"
            cell.detailTextLabel?.text = "1.0.0"
            return cell
            
        default:
            return UITableViewCell()
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            switch indexPath.row {
            case 0:
                showFontPicker()
            case 1:
                showFontSizePicker()
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 2 { // Layout settings with sliders
            return 80
        }
        return 44
    }
    
    // MARK: - Pickers
    private func showFontPicker() {
        let alertController = UIAlertController(title: "Select Font", message: nil, preferredStyle: .actionSheet)
        
        for font in fonts {
            let action = UIAlertAction(title: font, style: .default) { [weak self] _ in
                self?.settings.fontName = font
                self?.tableView.reloadData()
            }
            if font == settings.fontName {
                action.setValue(true, forKey: "checked")
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            if let cell = tableView.cellForRow(at: IndexPath(row: 0, section: 0)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alertController, animated: true)
    }
    
    private func showFontSizePicker() {
        let alertController = UIAlertController(title: "Font Size", message: nil, preferredStyle: .actionSheet)
        
        for size in fontSizes {
            let action = UIAlertAction(title: "\(Int(size))pt", style: .default) { [weak self] _ in
                self?.settings.fontSize = size
                self?.tableView.reloadData()
            }
            if size == settings.fontSize {
                action.setValue(true, forKey: "checked")
            }
            alertController.addAction(action)
        }
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        
        if let popover = alertController.popoverPresentationController {
            if let cell = tableView.cellForRow(at: IndexPath(row: 1, section: 0)) {
                popover.sourceView = cell
                popover.sourceRect = cell.bounds
            }
        }
        
        present(alertController, animated: true)
    }
}

