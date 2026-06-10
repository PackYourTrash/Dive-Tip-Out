//
//  Dive_Tip_OutApp.swift
//  Dive Tip-Out
//
//  Created by david pamatz on 6/9/26.
//

import SwiftUI

@main
struct Dive_Tip_OutApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var viewModel = TipOutViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onChange(of: scenePhase) { newPhase in
                    if newPhase == .active {
                        viewModel.resetIfNeededForNewDay()
                    }
                }
        }
    }
}
