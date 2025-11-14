//
//  MenuBarKeyboardShortcut.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit

class MenuBarKeyboardShortcut {
    var onShortcutPressed: (() -> Void)?
    var onShortcutReleased: (() -> Void)?
    
    private var eventMonitor: Any?
    private var isModifiersPressed = false
    private var isSelectionActive = false
    
    init() {
        setupModifierMonitoring()
    }
    
    deinit {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    private func setupModifierMonitoring() {
        // Monitor modifier key changes globally
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleModifierChange(event: event)
        }
        
        // Also monitor locally for when app is active
        NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleModifierChange(event: event)
            return event
        }
    }
    
    private func handleModifierChange(event: NSEvent) {
        let requiredModifiers: NSEvent.ModifierFlags = [.shift, .control, .option]
        let currentModifiers = event.modifierFlags.intersection([.shift, .control, .option])
        
        let allModifiersPressed = currentModifiers.contains(.shift) && 
                                  currentModifiers.contains(.control) && 
                                  currentModifiers.contains(.option)
        
        if allModifiersPressed && !isModifiersPressed {
            // All three modifiers just pressed together - start selection
            isModifiersPressed = true
            isSelectionActive = true
            print("🎯 [MenuBarKeyboardShortcut] All modifiers pressed (SHIFT+CTRL+OPT), starting selection")
            DispatchQueue.main.async { [weak self] in
                self?.onShortcutPressed?()
            }
        } else if !allModifiersPressed && isModifiersPressed {
            // One or more modifiers released
            isModifiersPressed = false
            if isSelectionActive {
                print("🎯 [MenuBarKeyboardShortcut] Modifiers released, canceling selection")
                isSelectionActive = false
                DispatchQueue.main.async { [weak self] in
                    self?.onShortcutReleased?()
                }
            }
        }
    }
    
    /// Call this when a selection is completed to prevent cancellation on modifier release
    func markSelectionCompleted() {
        isSelectionActive = false
    }
}

