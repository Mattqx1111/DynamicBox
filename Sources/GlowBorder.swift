import SwiftUI

struct NotchShape: Shape {
    var cornerRadius: CGFloat
    var isFlushToTop: Bool = true
    
    var animatableData: CGFloat {
        get { cornerRadius }
        set { cornerRadius = newValue }
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let w = rect.width
        let h = rect.height
        let r = cornerRadius
        
        if isFlushToTop {
            path.move(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 0, y: max(0, h - r)))
            path.addQuadCurve(to: CGPoint(x: min(r, w / 2), y: h), control: CGPoint(x: 0, y: h))
            path.addLine(to: CGPoint(x: max(w - r, w / 2), y: h))
            path.addQuadCurve(to: CGPoint(x: w, y: max(0, h - r)), control: CGPoint(x: w, y: h))
            path.addLine(to: CGPoint(x: w, y: 0))
            path.closeSubpath()
        } else {
            path.addRoundedRect(in: rect, cornerSize: CGSize(width: r, height: r))
        }
        
        return path
    }
}

struct CleanNativeBorderModifier: ViewModifier {
    var isExpanded: Bool
    var cornerRadius: CGFloat
    var isFlushToTop: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isExpanded {
                        NotchShape(cornerRadius: cornerRadius, isFlushToTop: isFlushToTop)
                            .stroke(Color.white.opacity(0.12), lineWidth: 0.5)
                    } else {
                        EmptyView()
                    }
                }
            )
    }
}

extension View {
    func notchBorder(isExpanded: Bool, cornerRadius: CGFloat = 20, isFlushToTop: Bool = true) -> some View {
        self.modifier(CleanNativeBorderModifier(isExpanded: isExpanded, cornerRadius: cornerRadius, isFlushToTop: isFlushToTop))
    }
}
