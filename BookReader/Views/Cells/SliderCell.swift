//
//  SliderCell.swift
//  BookReader
//
//  Created by Abdulaziz dot on 28/07/2025.
//

import UIKit

class SliderCell: UITableViewCell {
    private let titleLabel = UILabel()
    private let valueLabel = UILabel()
    private let slider = UISlider()
    private var onChange: ((Float) -> Void)?
    
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        selectionStyle = .none
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        valueLabel.translatesAutoresizingMaskIntoConstraints = false
        slider.translatesAutoresizingMaskIntoConstraints = false
        
        valueLabel.textAlignment = .right
        valueLabel.textColor = .secondaryLabel
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(valueLabel)
        contentView.addSubview(slider)
        
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            valueLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            valueLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 10),
            
            slider.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            slider.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            slider.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10)
        ])
        
        slider.addTarget(self, action: #selector(sliderChanged), for: .valueChanged)
    }
    
    func configure(title: String, value: Float, minValue: Float, maxValue: Float, onChange: @escaping (Float) -> Void) {
        titleLabel.text = title
        slider.minimumValue = minValue
        slider.maximumValue = maxValue
        slider.value = value
        updateValueLabel()
        self.onChange = onChange
    }
    
    @objc private func sliderChanged() {
        updateValueLabel()
        onChange?(slider.value)
    }
    
    private func updateValueLabel() {
        if slider.maximumValue > 10 {
            valueLabel.text = "\(Int(slider.value))"
        } else {
            valueLabel.text = String(format: "%.1f", slider.value)
        }
    }
}