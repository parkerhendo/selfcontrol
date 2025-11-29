//
//  PlistListner.swift
//  SelfControlExtension
//
//  Created by Satendra Singh on 16/08/25.
//

import Foundation
import Network
import os.log

final class ChromeExtensionRequestListner: NSObject, ObservableObject {
    private var isChromeStatusSetInExtension: Bool = false
    var listener: NWListener? = try! NWListener(using: .tcp, on: 8080)
    var blockeddomainFetcher: (() -> [String])?
    
    func startListening() {
        os_log("[SC] 🔍] PlistListner startListening")
//        let objects: [[String: Any]] = [
//            ["id": 1, "name": "Alice", "status": "running"],
//            ["id": 2, "name": "Bob", "status": "stopped"],
//            ["id": 3, "name": "Charlie", "status": "idle"]
//        ]
        listener = try! NWListener(using: .tcp, on: 8080)
        listener?.newConnectionHandler = { conn in
            
            Task { @MainActor in
                print("newConnectionHandler isEnabled: \(NetworkExtensionState.shared.isEnabled)")
                if NetworkExtensionState.shared.isEnabled == true && NetworkExtensionState.shared.isChromeExtensionEnabled == false {
                    NetworkExtensionState.shared.isChromeExtensionEnabled  = IPCConnection.shared.sendMessageToSetActiveBrowserExtension(ActiveBrowserExtensios.chrome.rawValue, state: true)
                    NetworkExtensionState.shared.printAll()
                }
            }
            let blockedDomainList: [String] = self.blockeddomainFetcher?() ?? []
            let blockedUrls = ["blocked": blockedDomainList]
            let jsonData = try! JSONSerialization.data(withJSONObject: blockedUrls, options: [])
            let jsonString = String(data: jsonData, encoding: .utf8)!

            os_log("[SC] 🔍] PlistListner newConnectionHandler")
            conn.start(queue: DispatchQueue.global(qos: .userInitiated))
//            conn.receiveMessage { data, _, _, _ in
                os_log("[SC] 🔍] PlistListner conn.receiveMessage")
            let response = """
            HTTP/1.1 200 OK\r
            Content-Type: application/json\r
            Access-Control-Allow-Origin: *\r
            \r
            \(jsonString)
            """
            conn.send(content: response.data(using: .utf8), contentContext: .finalMessage , completion: .contentProcessed { error in
                    os_log("[SC] 🔍] PlistListner Sent response:\(error)")
//                    conn.cancel()
                
                })
//            }
            
            conn.stateUpdateHandler = { state in
                if state == .ready {
                    
                    os_log("[SC] 🔍] PlistListner stateUpdateHandler ready")
                }
            }
        }
        listener?.start(queue: DispatchQueue.global(qos: .userInitiated))
//        RunLoop.main.run()
    }
}
