//
//  HoverButtonStyle.swift
//  Shed
//
//  A borderless icon button that grows slightly on hover and dips on press,
//  giving transport controls a tactile, native feel.
//

import SwiftUI

struct HoverButtonStyle: ButtonStyle {
    var hoverScale: CGFloat = 1.12
    var pressedScale: CGFloat = 0.9

    func makeBody(configuration: Configuration) -> some View {
        Hovering(configuration: configuration, hoverScale: hoverScale, pressedScale: pressedScale)
    }

    private struct Hovering: View {
        let configuration: ButtonStyle.Configuration
        let hoverScale: CGFloat
        let pressedScale: CGFloat
        @State private var hovering = false

        var body: some View {
            configuration.label
                .scaleEffect(configuration.isPressed ? pressedScale : (hovering ? hoverScale : 1))
                .opacity(configuration.isPressed ? 0.7 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(.spring(response: 0.3, dampingFraction: 0.65), value: hovering)
                .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
        }
    }
}
