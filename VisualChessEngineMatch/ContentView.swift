import SwiftUI

/// Placeholder top-level view. The match UI is assembled in a later step.
struct ContentView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkerboard.rectangle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Visual Engine Battle")
                .font(.title).bold()
            Text("Two chess engines, one match.")
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 680, minHeight: 600)
        .padding()
    }
}

#Preview {
    ContentView()
}
