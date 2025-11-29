//
//  SafariExtensionManager.swift
//  SelfControl
//
//  Created by Satendra Singh on 24/11/25.
//

import Foundation

final class SafariExtensionManager: ObservableObject {
    static let shared = SafariExtensionManager()
    private let appGroup = "group.com.application.SelfControl.corebits"
    var onChange: (() -> Void)?
    private var isReady: Bool = false
    
    private init() {
        NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults(suiteName: appGroup),
            queue: .main
        ) { notification in
            let shared = UserDefaults(suiteName: self.appGroup)
            print("Received from extension:", shared?.string(forKey: "ready") ?? "")
            if let value = shared?.bool(forKey: "ready"){
                print("Ready now:")
                if self.isReady == false {
                    self.onChange?()
                    self.isReady = true
                }
            }
        }
    }
    
    var isExtensionReady: Bool {
        return UserDefaults(suiteName: appGroup)?.bool(forKey: "ready") == true
    }
}
