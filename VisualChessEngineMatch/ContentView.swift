import SwiftUI

/// Main container view that switches between configuration and match visualization.
struct ContentView: View {
    @StateObject private var orchestrator = MatchOrchestrator()
    @State private var config = MatchConfig.standard()
    @State private var isShowingMatch = false
    
    var body: some View {
        ZStack {
            if isShowingMatch {
                matchOverlay()
            } else {
                MatchConfigView(config: $config, onStart: {
                    orchestrator.startMatch(config: config)
                    isShowingMatch = true
                })
            }
        }
        .frame(minWidth: 800, minHeight: 650)
    }
    
    private func matchOverlay() -> some View {
        MatchView(orchestrator: orchestrator)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button(action: {
                        orchestrator.stopMatch()
                        isShowingMatch = false
                    }) {
                        Label("Stop Match", systemImage: "stop.fill")
                    }
                }
            }
    }
}

#Preview {
    ContentView()
}
