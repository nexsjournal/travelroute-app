//
//  travelrouteApp.swift
//  travelroute
//
//  Created by LexRay on 2026/2/3.
//

import SwiftUI
import SwiftData

@main
struct travelrouteApp: App {
    @StateObject private var appEnvironment = AppEnvironment.shared
    
    var body: some Scene {
        WindowGroup {
            HomeView()
        }
        .modelContainer(appEnvironment.modelContainer)
    }
}
