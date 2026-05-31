import SwiftUI

/// View for configuring a new engine match.
struct MatchConfigView: View {
    @Binding var config: MatchConfig
    var onStart: () -> Void
    
    @State private var timeMinutes: Double = 5
    @State private var incrementSeconds: Double = 0.1
    
    var body: some View {
        Form {
            Section("Engines") {
                engineSection(name: "Engine 1 (Starts White)", config: $config.engine1)
                engineSection(name: "Engine 2 (Starts Black)", config: $config.engine2)
            }
            
            Section("Time Control") {
                HStack {
                    Text("Time per Game (min)")
                    Spacer()
                    TextField("", value: $timeMinutes, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("Increment per Move (sec)")
                    Spacer()
                    TextField("", value: $incrementSeconds, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
            }
            
            Section("Match Parameters") {
                Stepper("Number of Mini-matches: \(config.miniMatchCount)", value: $config.miniMatchCount, in: 1...100)
                
                HStack {
                    Text("EPD Openings File")
                    Spacer()
                    TextField("Bundled default", text: Binding(
                        get: { config.epdFilePath ?? "" },
                        set: { config.epdFilePath = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 200)
                }
                
                HStack {
                    Text("PGN Log Path")
                    Spacer()
                    TextField("match.pgn", text: Binding(
                        get: { config.pgnLogPath ?? "" },
                        set: { config.pgnLogPath = $0.isEmpty ? nil : $0 }
                    ))
                    .frame(width: 200)
                }
            }
            
            Section {
                Button(action: {
                    updateTimeControl()
                    onStart()
                }) {
                    Text("Start Match")
                        .frame(maxWidth: .infinity)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
        .formStyle(.grouped)
        .frame(minWidth: 500, minHeight: 600)
        .onAppear {
            timeMinutes = config.engine1.timePerGame / 60.0
            incrementSeconds = config.engine1.incrementPerMove
        }
    }
    
    private func engineSection(name: String, config: Binding<EngineConfig>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(name).font(.headline)
            
            HStack {
                Text("Name")
                TextField("Friendly Name", text: Binding(
                    get: { config.wrappedValue.name },
                    set: { config.wrappedValue.name = $0.trimmingCharacters(in: .whitespaces) }
                ))
            }
            
            HStack {
                Text("Path")
                TextField("Binary Path", text: Binding(
                    get: { config.wrappedValue.binaryPath },
                    set: { config.wrappedValue.binaryPath = $0.trimmingCharacters(in: .whitespaces) }
                ))
            }
        }
        .padding(.vertical, 4)
    }
    
    private func updateTimeControl() {
        let totalTime = timeMinutes * 60.0
        config.engine1.timePerGame = totalTime
        config.engine2.timePerGame = totalTime
        config.engine1.incrementPerMove = incrementSeconds
        config.engine2.incrementPerMove = incrementSeconds
    }
}

#Preview {
    MatchConfigView(config: .constant(.standard()), onStart: {})
}
