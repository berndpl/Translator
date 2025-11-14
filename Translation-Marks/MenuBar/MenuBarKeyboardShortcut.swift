//
//  MenuBarKeyboardShortcut.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import AppKit
import Carbon

class MenuBarKeyboardShortcut {
    var onShortcutPressed: (() -> Void)?
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    
    init() {
        setupGlobalShortcut()
    }
    
    deinit {
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let hotKeyRef = hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
    }
    
    private func setupGlobalShortcut() {
        let eventSpec = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        ]
        
        var hotKeyID = EventHotKeyID()
        hotKeyID.signature = OSType(fourCharCodeFrom: "TRMK")
        hotKeyID.id = 1
        
        let modifiers = UInt32(cmdKey | controlKey | optionKey)
        let keyCode = UInt32(0x11) // 'T' key
        
        var hotKeyRef: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        guard status == noErr, let ref = hotKeyRef else {
            print("Failed to register hot key")
            return
        }
        
        self.hotKeyRef = ref
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { (nextHandler, theEvent, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    theEvent,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                
                guard status == noErr else { return status }
                
                let manager = Unmanaged<MenuBarKeyboardShortcut>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    manager.onShortcutPressed?()
                }
                
                return noErr
            },
            1,
            eventSpec,
            selfPtr,
            &eventHandler
        )
        
        guard handlerStatus == noErr else {
            print("Failed to install event handler")
            return
        }
    }
}

// Extension for OSType
extension OSType {
    init(fourCharCodeFrom string: String) {
        precondition(string.count == 4)
        var result: UInt32 = 0
        for char in string.utf8 {
            result = (result << 8) + UInt32(char)
        }
        self = result
    }
}

