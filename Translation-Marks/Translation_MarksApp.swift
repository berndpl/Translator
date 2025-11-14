//
//  Translation_MarksApp.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import SwiftUI

@main
struct Translation_MarksApp: App {
    @StateObject private var marksManager = MarksManager()
    
    var body: some Scene {
        MenuBarExtra("Translation Marks", image: "MenuBarIcon") {
            MenuBarView()
                .environmentObject(marksManager)
        }
        .menuBarExtraStyle(.window)
    }
}

