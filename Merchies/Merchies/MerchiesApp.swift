//
//  MerchiesApp.swift
//  Merchies
//
//  Created by Jason Kolbenheyer on 5/21/25.
//

import SwiftUI
import Firebase
import Foundation

@main
struct MerchPitApp: App {
    
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
