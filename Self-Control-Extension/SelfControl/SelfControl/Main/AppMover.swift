//
//  AppMover.swift
//  SelfControl
//
//  Created by Satendra Singh on 05/12/25.
//

import Cocoa
import os.log

final class AppMover {
    
    static func moveIfNeeded() {
        // 1. Check current app path
        let bundleURL = Bundle.main.bundleURL
        let fm = FileManager.default
        
        //        Prefer /Applications, fallback to ~/Applications
        let appName = bundleURL.lastPathComponent
        let systemApplicationsDir = URL(fileURLWithPath: "/Applications", isDirectory: true)
        let userApplicationsDir = fm.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        
        let destinations = [ systemApplicationsDir, userApplicationsDir ]
        
        // 3. If already inside one of those destinations (and not in DMG, etc), skip
        if destinations.contains(where: { bundleURL.deletingLastPathComponent() == $0 }) {
            return // already correct place
        }
        
        // 4. Ask user via alert
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Move to Applications Folder?"
            alert.informativeText = "Would you like to move this app to your Applications folder? It must quit and relaunch."
            alert.addButton(withTitle: "Move to Applications Folder")
            alert.addButton(withTitle: "Do Not Move")
            let response = alert.runModal()
            if response == .alertFirstButtonReturn {
                performMove(to: destinations.first!, bundleURL: bundleURL)
            }
        }
    }
    
    private static func performMove(to appDir: URL, bundleURL: URL) {
        let fm = FileManager.default
        
        // Ensure destination directory exists
        do {
            try fm.createDirectory(at: appDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            os_log("[SC] 🔍] Could not create Applications directory: %@", error.localizedDescription)
            print("Could not create Applications directory: \(error)")
        }
        
        // Destination path for the app
        let destURL = appDir.appendingPathComponent(bundleURL.lastPathComponent)
        
        // If exists, maybe prompt to overwrite
        if fm.fileExists(atPath: destURL.path) {
            // For simplicity: remove existing
            do {
                try fm.removeItem(at: destURL)
            } catch {
                os_log("[SC] 🔍] Could not remove existing app at destination: %@", error.localizedDescription)
                print("Could not remove existing app at destination: \(error)")
                // Handle error (maybe ask user, or abort)
            }
        }
        
        do {
            // Copy the bundle
            try fm.moveItem(at: bundleURL, to: destURL)
            
            // Clear quarantine attribute (so first launch doesn’t ask gatekeeper)
            removeQuarantineRecursively(at: destURL)
            // Relaunch the copied app
            let config = NSWorkspace.OpenConfiguration()
            NSWorkspace.shared.openApplication(at: destURL, configuration: config) { (app, err) in
                if let err = err {
                    os_log("[SC] 🔍] Failed to relaunch at dest: %@", err.localizedDescription)
                    print("Failed to relaunch at dest: \(err)")
                }
                // After launching new instance, quit old one
                exit(0)
            }
            
        } catch {
            os_log("[SC] 🔍] Error copying app to Applications: %@", error.localizedDescription)
            print("Error copying app to Applications: \(error)")
            // Optionally ask for authorization and retry
        }
    }

    private static func removeQuarantineAttribute(from url: URL) {
        let path = url.path

        // Check if attribute exists
        let attrName = "com.apple.quarantine"

        let result = getxattr(path, attrName, nil, 0, 0, 0)
        if result >= 0 {
            // The attribute exists → remove it
            let removeResult = removexattr(path, attrName, 0)
            if removeResult == 0 {
                os_log("[SC] 🔍] Successfully removed quarantine attribute")
                print("Successfully removed quarantine attribute")
            } else {
                os_log("[SC] 🔍] Failed to remove quarantine attribute")
                print("Failed to remove quarantine attribute")
            }
        } else {
            os_log("[SC] 🔍] No quarantine attribute found")
            print("No quarantine attribute found")
        }
    }

    private static func removeQuarantineRecursively(at url: URL) {
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator {
                removeQuarantineAttribute(from: fileURL)
            }
        }
        removeQuarantineAttribute(from: url) // root bundle
    }
}
