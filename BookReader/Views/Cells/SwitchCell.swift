//
//  SwitchCell.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

class SwitchCell: UITableViewCell {
    private let switchControl = UISwitch()
    private var onChange: ((Bool) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        accessoryView = switchControl
        switchControl.addTarget(self, action: #selector(switchChanged), for: .valueChanged)
    }
    
    func configure(title: String, isOn: Bool, onChange: @escaping (Bool) -> Void) {
        textLabel?.text = title
        switchControl.isOn = isOn
        self.onChange = onChange
    }
    
    @objc private func switchChanged() {
        onChange?(switchControl.isOn)
    }
}