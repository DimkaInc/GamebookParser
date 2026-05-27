import SwiftUI
struct GraphCanvasView: View {
    let book: Book
    // MARK: - BODY
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let pages =
                    book.pages.keys.sorted()
                let radius: CGFloat = 28
                var positions:
                    [Int: CGPoint] = [:]
                // NODE POSITIONS
                for (index, page)
                    in pages.enumerated()
                {
                    let angle =
                        Double(index)
                        / Double(
                            max(pages.count, 1)
                        )
                        * Double.pi * 2
                    let x =
                        size.width / 2
                        + cos(angle)
                        * size.width * 0.35
                    let y =
                        size.height / 2
                        + sin(angle)
                        * size.height * 0.35
                    positions[page] =
                        CGPoint(x: x, y: y)
                }
                // EDGES
                drawEdges(
                    context: context,
                    positions: positions,
                    pages: pages
                )
                // NODES
                drawNodes(
                    context: context,
                    positions: positions,
                    radius: radius,
                    pages: pages
                )
            }
        }
    }
}

import SwiftUI
extension GraphCanvasView {
    // MARK: - DRAW EDGES
    func drawEdges(
        context: GraphicsContext,
        positions: [Int: CGPoint],
        pages: [Int]
    ) {
        for pageID in pages {
            guard let page =
                    book.pages[pageID],
                  let start =
                    positions[pageID]
            else {
                continue
            }
            for target in page
                .actions
                .choice
                .keys
            {
                guard let end =
                        positions[target]
                else {
                    continue
                }
                var path = Path()
                path.move(to: start)
                path.addLine(to: end)
                context.stroke(
                    path,
                    with: .color(.blue),
                    lineWidth: 2
                )
            }
        }
    }
    // MARK: - DRAW NODES
    func drawNodes(
        context: GraphicsContext,
        positions: [Int: CGPoint],
        radius: CGFloat,
        pages: [Int]
    ) {
        for pageID in pages {
            guard let point =
                    positions[pageID]
            else {
                continue
            }
            let rect = CGRect(
                x: point.x - radius,
                y: point.y - radius,
                width: radius * 2,
                height: radius * 2
            )
            context.fill(
                Path(ellipseIn: rect),
                with: .color(.orange)
            )
            context.draw(
                Text("\(pageID)")
                    .font(.caption)
                    .foregroundColor(.black),
                at: point
            )
        }
    }
}

