//
//  CustomLayoutButton.swift
//  MeshApp
//
//  Created by Dudley Du on 2019/3/26.
//  Copyright © 2019 Cypress Semiconductor. All rights reserved.
//

import UIKit


class CustomLayoutButton: UIButton {
    override init(frame: CGRect) {
        super.init(frame: frame)

        customLayoutInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        customLayoutInit()
    }

    func customLayoutInit() {
        guard let text = self.titleLabel?.text else {
            return
        }

        let titleText = text.replacingOccurrences(of: " ", with: "\n")
        let words = titleText.components(separatedBy: "\n")
        self.setTitle(titleText, for: .normal)
        self.titleLabel?.textAlignment = .center
        self.titleLabel?.lineBreakMode = .byWordWrapping
        self.titleLabel?.numberOfLines = words.count
    }
}
