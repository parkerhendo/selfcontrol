//
//  ProxyPreferences.swift
//  SelfControl
//
//  Created by Satendra Singh on 12/07/25.
//


import Foundation

struct ProxyPreferences {
//    static let appGroup = "X6FQ433AWK.com.application.SelfControl.Extension"
    private static let blockedDomainsKey = "BlockedDomains"
    private static let isSafariExtensionKey: String = "isSafariExtensionKey"
    private static let isChromeExtensionKey: String = "isChromeExtensionKey"
    private static let defaults = UserDefaults.standard
    static func getBlockedDomains() -> [String] {
        return defaults.stringArray(forKey: blockedDomainsKey) ?? []
    }
    
    static func setBlockedDomains(_ domains: [String]) {
        defaults.set(domains, forKey: blockedDomainsKey)
    }
    
    static func setSafariExtensionState(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: isSafariExtensionKey)

    }
    
    static func setChromeExtensionState(_ isEnabled: Bool) {
        defaults.set(isEnabled, forKey: isChromeExtensionKey)
    }
    
    static func safariExtensionState() {
        defaults.value(forKey: isSafariExtensionKey)

    }
    
    static func chromeExtensionState() {
        defaults.value(forKey: isChromeExtensionKey)
    }
}
