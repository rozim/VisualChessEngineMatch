import SwiftUI

/// View for configuring a new engine match.
struct MatchConfigView: View {
    @Binding var config: MatchConfig
    var onStart: () -> Void
    
    @State private var timeSeconds: Int = 10
    @State private var incrementSeconds: Double = 0.1
    @State private var nodeLimit: Int = 10000
    
    var body: some View {
        Form {
            Section("Match Mode") {
                Picker("Type", selection: $config.mode) {
                    Text("Time Control").tag(MatchMode.time)
                    Text("Node Limit").tag(MatchMode.nodes)
                }
                .pickerStyle(.segmented)
            }

            Section("Engines") {
                engineSection(name: "Engine 1 (Starts White)", config: $config.engine1)
                engineSection(name: "Engine 2 (Starts Black)", config: $config.engine2)
            }
            
            if config.mode == .time {
                Section("Time Control") {
                    HStack {
                        Text("Time per Game (sec)")
                        Spacer()
                        TextField("", value: $timeSeconds, format: .number)
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
            } else {
                Section("Node Limit") {
                    HStack {
                        Text("Nodes per Move")
                        Spacer()
                        TextField("", value: $nodeLimit, format: .number)
                            .frame(width: 100)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            
            Section("Match Parameters") {
                HStack {
                    Text("Number of Mini-matches")
                    Spacer()
                    TextField("", value: $config.miniMatchCount, format: .number)
                        .frame(width: 60)
                        .multilineTextAlignment(.trailing)
                }
                
                HStack {
                    Text("EPD Openings File")
                    Spacer()
                    TextField("Bundled default", text: Binding(
                        get: { config.epdFilePath ?? "" },
                        set: { config.epdFilePath = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0.trimmingCharacters(in: .whitespaces) }
                    ))
                    .frame(width: 200)
                }
                
                HStack {
                    Text("PGN Log Path")
                    Spacer()
                    TextField("match.pgn", text: Binding(
                        get: { config.pgnLogPath ?? "" },
                        set: { config.pgnLogPath = $0.trimmingCharacters(in: .whitespaces).isEmpty ? nil : $0.trimmingCharacters(in: .whitespaces) }
                    ))
                    .frame(width: 200)
                }
            }
            
            Section {
                Button(action: {
                    updateMatchConfig()
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
        .frame(minWidth: 500, minHeight: 650)
        .onAppear {
            timeSeconds = config.engine1.timePerGame
            incrementSeconds = config.engine1.incrementPerMove
            nodeLimit = config.engine1.nodeLimit
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
    
    private func updateMatchConfig() {
        config.engine1.timePerGame = timeSeconds
        config.engine2.timePerGame = timeSeconds
        config.engine1.incrementPerMove = incrementSeconds
        config.engine2.incrementPerMove = incrementSeconds
        config.engine1.nodeLimit = nodeLimit
        config.engine2.nodeLimit = nodeLimit
    }
}

#Preview {
    MatchConfigView(config: .constant(.standard()), onStart: {})
}
