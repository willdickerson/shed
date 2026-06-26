//
//  TimeRulerView.swift
//  Shed
//
//  Thin time axis under the main waveform, labelled for the visible window.
//

import SwiftUI

struct TimeRulerView: View {
    let viewport: Viewport
    let duration: TimeInterval

    private static let niceSteps: [TimeInterval] = [1, 2, 5, 10, 15, 30, 60, 120, 300, 600]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let total = max(duration, 0.0001)
            let visibleStart = viewport.clampedStart(total: total)
            let visibleDuration = viewport.visibleDuration(total: total)
            let step = niceStep(for: visibleDuration)
            let first = (visibleStart / step).rounded(.up) * step

            ZStack(alignment: .topLeading) {
                ForEach(ticks(from: first, step: step, end: visibleStart + visibleDuration), id: \.self) { tick in
                    let x = CGFloat((tick - visibleStart) / visibleDuration) * width
                    Text(TimeFormatting.clock(tick))
                        .font(.caption2)
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: x, y: 7)
                }
            }
        }
    }

    private func ticks(from first: TimeInterval, step: TimeInterval, end: TimeInterval) -> [TimeInterval] {
        guard step > 0, first.isFinite else { return [] }
        var result: [TimeInterval] = []
        var t = first
        while t <= end + 0.001 && result.count < 64 {
            result.append(t)
            t += step
        }
        return result
    }

    private func niceStep(for visibleDuration: TimeInterval) -> TimeInterval {
        let target = visibleDuration / 6
        return Self.niceSteps.first(where: { $0 >= target }) ?? Self.niceSteps.last ?? 60
    }
}
