import SwiftUI

struct PulseOverlay: ViewModifier {
    let active: Bool
    let strong: Bool
    let enabled: Bool
    let color: Color
    @State private var pulsing = false

    func body(content: Content) -> some View {
        content
            .overlay {
                if active && enabled {
                    RoundedRectangle(cornerRadius: 30, style: .continuous)
                        .stroke(color.opacity(strong ? 0.55 : 0.35), lineWidth: strong ? 2.2 : 1.4)
                        .scaleEffect(pulsing ? (strong ? 1.08 : 1.04) : 0.98)
                        .opacity(pulsing ? 0.08 : 0.7)
                        .animation(
                            .easeInOut(duration: strong ? 0.72 : 1.25).repeatForever(autoreverses: true),
                            value: pulsing
                        )
                        .onAppear { pulsing = true }
                }
            }
    }
}

struct ShakeEffect: GeometryEffect {
    var travelDistance: CGFloat = 4
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(
                translationX: travelDistance * sin(animatableData * .pi * shakesPerUnit),
                y: 0
            )
        )
    }
}
