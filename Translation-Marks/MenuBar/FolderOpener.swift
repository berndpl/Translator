//
//  FolderOpener.swift
//  Translation-Marks
//
//  Created by Bernd Plontsch on 13.11.2025.
//

import Foundation
import AppKit

struct FolderOpener {
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}


