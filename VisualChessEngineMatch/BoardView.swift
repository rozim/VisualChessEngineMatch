import SwiftUI

/// Chess board: renders the current position from White's perspective.
/// Can be interactive (for manual testing) or read-only (for engine matches).
struct BoardView: View {
    @ObservedObject var controller: GameController
    var isInteractive: Bool = true

    // Light/dark square colors and highlight tints.
    private let lightColor = Color(red: 0.93, green: 0.85, blue: 0.71)
    private let darkColor = Color(red: 0.71, green: 0.53, blue: 0.39)
    private let selectionColor = Color.yellow.opacity(0.45)
    private let lastMoveColor = Color.green.opacity(0.28)
    private let checkColor = Color.red.opacity(0.45)

    @State private var selectedSquare: Square?
    @State private var legalTargets: Set<Square> = []
    @State private var draggingFrom: Square?
    @State private var dragLocation: CGPoint = .zero
    @State private var promotionPrompt: (from: Square, to: Square)?

    private let boardSpace = "board"

    var body: some View {
        GeometryReader { geo in
            let boardSize = min(geo.size.width, geo.size.height)
            let squareSize = boardSize / 8

            ZStack(alignment: .topLeading) {
                squaresLayer(squareSize: squareSize)
                piecesLayer(squareSize: squareSize)
                if draggingFrom != nil { draggedPiece(squareSize: squareSize) }
                if let prompt = promotionPrompt {
                    promotionOverlay(prompt: prompt, boardSize: boardSize, squareSize: squareSize)
                }
            }
            .frame(width: boardSize, height: boardSize)
            .coordinateSpace(name: boardSpace)
            .gesture(
                isInteractive ?
                SpatialTapGesture(coordinateSpace: .named(boardSpace))
                    .onEnded { value in
                        guard promotionPrompt == nil else { return }
                        handleTap(square(at: value.location, squareSize: squareSize))
                    }
                : nil
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    // MARK: - Layers

    private func squaresLayer(squareSize: CGFloat) -> some View {
        ForEach(0..<8, id: \.self) { row in
            ForEach(0..<8, id: \.self) { col in
                let square = Square(file: col, rank: 7 - row)
                squareCell(square, row: row, col: col, size: squareSize)
            }
        }
    }

    private func squareCell(_ square: Square, row: Int, col: Int, size: CGFloat) -> some View {
        let baseColor = square.color == .light ? lightColor : darkColor
        let labelColor = square.color == .light ? darkColor : lightColor
        return ZStack {
            Rectangle().fill(baseColor)
            if square == controller.checkedKingSquare {
                Rectangle().fill(checkColor)
            } else if square == draggingFrom || square == selectedSquare {
                Rectangle().fill(selectionColor)
            } else if square == controller.lastMove?.from || square == controller.lastMove?.to {
                Rectangle().fill(lastMoveColor)
            }
            // Legal-move indicator.
            if isInteractive && legalTargets.contains(square) {
                if controller.piece(at: square) == nil {
                    Circle().fill(Color.black.opacity(0.22))
                        .frame(width: size * 0.3, height: size * 0.3)
                } else {
                    Circle().strokeBorder(Color.black.opacity(0.3), lineWidth: size * 0.07)
                        .frame(width: size * 0.92, height: size * 0.92)
                }
            }
            coordinateLabels(square, labelColor: labelColor, size: size)
        }
        .frame(width: size, height: size)
        .position(x: (CGFloat(col) + 0.5) * size, y: (CGFloat(row) + 0.5) * size)
    }

    private func coordinateLabels(_ square: Square, labelColor: Color, size: CGFloat) -> some View {
        ZStack {
            if square.file == 0 {
                Text("\(square.rankNumber)")
                    .font(.system(size: max(8, size * 0.16), weight: .semibold))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(2)
            }
            if square.rank == 0 {
                Text(String(square.fileLetter))
                    .font(.system(size: max(8, size * 0.16), weight: .semibold))
                    .foregroundStyle(labelColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(2)
            }
        }
    }

    private func piecesLayer(squareSize: CGFloat) -> some View {
        ForEach(0..<64, id: \.self) { i in
            let square = Square(file: i % 8, rank: i / 8)
            if let piece = controller.piece(at: square), square != draggingFrom {
                pieceImage(piece, size: squareSize)
                    .position(center(of: square, size: squareSize))
                    .gesture(isInteractive ? dragGesture(for: square, squareSize: squareSize) : nil)
            }
        }
    }

    private func draggedPiece(squareSize: CGFloat) -> some View {
        Group {
            if let from = draggingFrom, let piece = controller.piece(at: from) {
                pieceImage(piece, size: squareSize)
                    .position(dragLocation)
                    .allowsHitTesting(false)
            }
        }
    }

    private func pieceImage(_ piece: Piece, size: CGFloat) -> some View {
        Image(piece.assetName)
            .resizable()
            .scaledToFit()
            .frame(width: size * 0.86, height: size * 0.86)
            .shadow(radius: draggingFrom != nil ? 2 : 0)
    }

    // MARK: - Promotion

    private func promotionOverlay(prompt: (from: Square, to: Square), boardSize: CGFloat, squareSize: CGFloat) -> some View {
        let color = controller.sideToMove
        return ZStack {
            Color.black.opacity(0.45)
            VStack(spacing: 10) {
                Text("Promote to").font(.headline).foregroundStyle(.white)
                HStack(spacing: 12) {
                    ForEach([PieceKind.queen, .rook, .bishop, .knight], id: \.self) { kind in
                        Button {
                            controller.attemptMove(from: prompt.from, to: prompt.to, promotion: kind)
                            clearSelection()
                            promotionPrompt = nil
                        } label: {
                            Image(Piece(color: color, kind: kind).assetName)
                                .resizable().scaledToFit()
                                .frame(width: squareSize * 0.8, height: squareSize * 0.8)
                                .padding(6)
                                .background(Color(white: 0.9))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(20)
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .frame(width: boardSize, height: boardSize)
    }

    // MARK: - Gestures

    private func dragGesture(for square: Square, squareSize: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(boardSpace))
            .onChanged { value in
                guard promotionPrompt == nil else { return }
                if draggingFrom == nil {
                    // Only pick up the side-to-move's own pieces.
                    guard let piece = controller.piece(at: square), piece.color == controller.sideToMove else { return }
                    beginSelection(square)
                    draggingFrom = square
                }
                dragLocation = value.location
            }
            .onEnded { value in
                guard promotionPrompt == nil else { return }
                defer { draggingFrom = nil }
                let dragDistance = hypot(value.translation.width, value.translation.height)
                if dragDistance < squareSize * 0.3 {
                    // Treated as a tap on this piece.
                    handleTap(square)
                } else if draggingFrom == square {
                    attempt(from: square, to: self.square(at: value.location, squareSize: squareSize))
                }
            }
    }

    private func handleTap(_ square: Square) {
        if let selected = selectedSquare, selected != square, legalTargets.contains(square) {
            attempt(from: selected, to: square)
        } else if selectedSquare == square {
            clearSelection()
        } else if let piece = controller.piece(at: square), piece.color == controller.sideToMove {
            beginSelection(square)
        } else {
            clearSelection()
        }
    }

    private func attempt(from: Square, to: Square) {
        switch controller.attemptMove(from: from, to: to) {
        case .made, .illegal:
            clearSelection()
        case .needsPromotion:
            promotionPrompt = (from, to)
        }
    }

    // MARK: - Helpers

    private func beginSelection(_ square: Square) {
        selectedSquare = square
        legalTargets = Set(controller.legalMoves(from: square).map { $0.to })
    }

    private func clearSelection() {
        selectedSquare = nil
        legalTargets = []
    }

    private func center(of square: Square, size: CGFloat) -> CGPoint {
        CGPoint(x: (CGFloat(square.file) + 0.5) * size,
                y: (CGFloat(7 - square.rank) + 0.5) * size)
    }

    private func square(at point: CGPoint, squareSize: CGFloat) -> Square {
        let col = min(7, max(0, Int(point.x / squareSize)))
        let row = min(7, max(0, Int(point.y / squareSize)))
        return Square(file: col, rank: 7 - row)
    }
}

#Preview {
    BoardView(controller: GameController())
        .frame(width: 480, height: 480)
}
