//
//  AppDelegate.swift
//  QuoteIt
//
//  Created by Jonah Blackmon on 5/16/25.
//

import UIKit
import FirebaseCore
import FirebaseFirestore
class AppDelegate: NSObject, UIApplicationDelegate {
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
}
