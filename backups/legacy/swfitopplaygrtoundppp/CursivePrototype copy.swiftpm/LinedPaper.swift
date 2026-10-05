import SwiftUI

struct LinedPaperBackground: View {
    let lineSpacing: CGFloat = 40
    let lineColor = Color.gray.opacity(0.3)

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                var y: CGFloat = 0
                while y < geometry.size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    y += lineSpacing
                }
            }
            .stroke(lineColor, lineWidth: 1)
        }
        .background(Color.white) // Ensure the paper has a white base
    }
}
