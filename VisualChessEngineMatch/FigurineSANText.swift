import SwiftUI

/// Helper view that renders a SAN move string (e.g., "♞f3" or "e4") 
/// with the chess figurine character at a larger size than the rest of the text.
struct FigurineSANText: View {
    let san: String
    var baseFont: Font = .body
    var figurineSize: CGFloat = 20
    
    private func isFigurine(_ c: Character) -> Bool {
        "♚♛♜♝♞♟".contains(c)
    }
    
    var body: some View {
        HStack(spacing: 0) {
            if let first = san.first, isFigurine(first) {
                Text(String(first))
                    .font(.system(size: figurineSize))
                Text(san.dropFirst())
                    .font(baseFont)
            } else if san.contains("=") {
                // Handle cases like "a8=♛"
                let parts = san.split(separator: "=")
                if parts.count == 2 {
                    Text(parts[0] + "=")
                        .font(baseFont)
                    if let firstFig = parts[1].first, isFigurine(firstFig) {
                        Text(String(firstFig))
                            .font(.system(size: figurineSize))
                        Text(parts[1].dropFirst())
                            .font(baseFont)
                    } else {
                        Text(parts[1])
                            .font(baseFont)
                    }
                } else {
                    Text(san).font(baseFont)
                }
            } else {
                Text(san).font(baseFont)
            }
        }
    }
}

/// A view that renders a full line of SAN moves with large figurines.
struct FigurineSANLine: View {
    let moves: [String]
    var baseFont: Font = .caption
    var figurineSize: CGFloat = 16
    
    var body: some View {
        // Use a simple HStack for the PV line to avoid complex layout issues
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(moves.indices, id: \.self) { i in
                    FigurineSANText(san: moves[i], baseFont: baseFont, figurineSize: figurineSize)
                }
            }
        }
    }
}
