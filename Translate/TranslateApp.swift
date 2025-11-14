//
//  TranslateApp.swift
//  Translate
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI

@main
struct TranslateApp: App {
    @StateObject private var marksManager = MarksManager()
    
    var body: some Scene {
        MenuBarExtra("Translate", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(marksManager)
        }
        .menuBarExtraStyle(.window)
    }
}

