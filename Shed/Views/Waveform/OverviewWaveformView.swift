//
//  OverviewWaveformView.swift
//  Shed
//
//  Miniature whole-song waveform with a draggable highlight showing the region
//  currently visible in the main waveform. Foundation for zoom navigation.
//

import SwiftUI

struct OverviewWaveformView: View {
    let waveform: WaveformData
    @Binding var viewport: Viewport
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let total = max(duration, 0.0001)
            let visibleStart = viewport.clampedStart(total: total)
            let visibleDuration = viewport.visibleDuration(total: total)
            let x0 = CGFloat(visibleStart / total) * size.width
            let x1 = CGFloat((visibleStart + visibleDuration) / total) * size.width

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in draw(in: &context, size: size) }

                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.blue.opacity(0.16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 3)
                            .strokeBorder(Color.blue.opacity(0.6), lineWidth: 1)
                    )
                    .frame(width: max(2, x1 - x0), height: size.height)
                    .position(x: (x0 + x1) / 2, y: size.height / 2)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0).onChanged { value in
                    let fraction = max(0, min(1, value.location.x / max(size.width, 1)))
                    viewport.center(on: Double(fraction) * total, total: total)
                }
            )
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 5))
        }
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let mid = size.height / 2
        let amplitudeScale = size.height / 2 - 2
        let bucketCount = waveform.bucketCount
        guard bucketCount > 0, amplitudeScale > 0 else { return }

        let peak = CGFloat(waveform.peak)
        let columns = max(1, Int(size.width))
        var path = Path()
        for column in 0..<columns {
            let b0 = bucketCount * column / columns
            let b1 = max(b0 + 1, bucketCount * (column + 1) / columns)
            var minVal: Float = 0
            var maxVal: Float = 0
            for bucket in b0..<min(b1, bucketCount) {
                minVal = min(minVal, waveform.mins[bucket])
                maxVal = max(maxVal, waveform.maxs[bucket])
            }
            let x = CGFloat(column)
            path.move(to: CGPoint(x: x, y: mid - (CGFloat(maxVal) / peak) * amplitudeScale))
            path.addLine(to: CGPoint(x: x, y: mid - (CGFloat(minVal) / peak) * amplitudeScale))
        }
        context.stroke(path, with: .color(Color(nsColor: .quaternaryLabelColor)), lineWidth: 1)
    }
}
