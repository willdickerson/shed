//
//  WaveformView.swift
//  Shed
//
//  SwiftUI Canvas waveform with click-to-seek, drag-to-create-loop, and
//  draggable loop handles. Peak buckets are aggregated to the pixel width on
//  each draw so it stays efficient for long files.
//

import SwiftUI

struct WaveformView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let waveform: WaveformData
    let onInteract: () -> Void

    @State private var dragMode: DragMode?
    @State private var previewLoop: LoopRegion?

    private let handleHitWidth: CGFloat = 7

    private enum DragMode: Equatable {
        case create(anchorTime: TimeInterval, startX: CGFloat)
        case moveStart
        case moveEnd
    }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let loop = previewLoop ?? viewModel.loopRegion

            Canvas { context, _ in
                draw(in: &context, size: size, loop: loop)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size))
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color(nsColor: .separatorColor)))
    }

    // MARK: - Drawing

    private func draw(in context: inout GraphicsContext, size: CGSize, loop: LoopRegion?) {
        let mid = size.height / 2
        let amplitudeScale = (size.height / 2) - 6
        let duration = max(viewModel.duration, 0.0001)

        // Loop region highlight.
        if let loop, loop.isUsable {
            let startX = x(for: loop.start, width: size.width, duration: duration)
            let endX = x(for: loop.end, width: size.width, duration: duration)
            let rect = CGRect(x: startX, y: 0, width: max(1, endX - startX), height: size.height)
            context.fill(Path(rect), with: .color(.accentColor.opacity(0.15)))
        }

        // Waveform peaks aggregated to pixel columns.
        var path = Path()
        let columns = max(1, Int(size.width))
        let bucketCount = waveform.bucketCount
        if bucketCount > 0 {
            let peak = CGFloat(waveform.peak)
            for column in 0..<columns {
                let startBucket = bucketCount * column / columns
                let endBucket = max(startBucket + 1, bucketCount * (column + 1) / columns)
                var minVal: Float = 0
                var maxVal: Float = 0
                for bucket in startBucket..<min(endBucket, bucketCount) {
                    minVal = min(minVal, waveform.mins[bucket])
                    maxVal = max(maxVal, waveform.maxs[bucket])
                }
                let x = CGFloat(column)
                let topY = mid - (CGFloat(maxVal) / peak) * amplitudeScale
                let bottomY = mid - (CGFloat(minVal) / peak) * amplitudeScale
                path.move(to: CGPoint(x: x, y: topY))
                path.addLine(to: CGPoint(x: x, y: bottomY))
            }
        }
        context.stroke(path, with: .color(.secondary.opacity(0.7)), lineWidth: 1)

        // Center baseline.
        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: mid))
        baseline.addLine(to: CGPoint(x: size.width, y: mid))
        context.stroke(baseline, with: .color(Color(nsColor: .separatorColor)), lineWidth: 0.5)

        // Loop handles.
        if let loop, loop.isUsable {
            drawHandle(&context, time: loop.start, size: size, duration: duration)
            drawHandle(&context, time: loop.end, size: size, duration: duration)
        }

        // Playhead.
        let playheadX = x(for: viewModel.currentTime, width: size.width, duration: duration)
        var playhead = Path()
        playhead.move(to: CGPoint(x: playheadX, y: 0))
        playhead.addLine(to: CGPoint(x: playheadX, y: size.height))
        context.stroke(playhead, with: .color(.accentColor), lineWidth: 2)
    }

    private func drawHandle(_ context: inout GraphicsContext, time: TimeInterval, size: CGSize, duration: TimeInterval) {
        let handleX = x(for: time, width: size.width, duration: duration)
        var path = Path()
        path.move(to: CGPoint(x: handleX, y: 0))
        path.addLine(to: CGPoint(x: handleX, y: size.height))
        context.stroke(path, with: .color(.accentColor.opacity(0.85)), lineWidth: 3)
    }

    // MARK: - Geometry helpers

    private func x(for time: TimeInterval, width: CGFloat, duration: TimeInterval) -> CGFloat {
        CGFloat(time / duration) * width
    }

    private func time(forX x: CGFloat, width: CGFloat) -> TimeInterval {
        let fraction = max(0, min(1, x / max(width, 1)))
        return Double(fraction) * viewModel.duration
    }

    // MARK: - Gesture

    private func dragGesture(size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let width = size.width
                let duration = max(viewModel.duration, 0.0001)

                if dragMode == nil {
                    onInteract()
                    dragMode = resolveMode(at: value.startLocation.x, width: width, duration: duration)
                }
                guard let mode = dragMode else { return }

                switch mode {
                case let .create(anchorTime, _):
                    previewLoop = LoopRegion(start: anchorTime, end: time(forX: value.location.x, width: width))
                case .moveStart:
                    let end = viewModel.loopRegion?.end ?? viewModel.duration
                    previewLoop = LoopRegion(start: time(forX: value.location.x, width: width), end: end)
                case .moveEnd:
                    let start = viewModel.loopRegion?.start ?? 0
                    previewLoop = LoopRegion(start: start, end: time(forX: value.location.x, width: width))
                }
            }
            .onEnded { value in
                let mode = dragMode
                let region = previewLoop
                dragMode = nil
                previewLoop = nil
                let width = size.width

                if case let .create(_, startX)? = mode,
                   abs(value.location.x - startX) < 4 {
                    // Negligible movement → treat as a click.
                    viewModel.handleWaveformClick(at: time(forX: value.location.x, width: width))
                    return
                }

                guard let region, region.isUsable else { return }
                switch mode {
                case .create:
                    // Drawing a loop enters loop mode immediately.
                    viewModel.createLoop(region)
                case .moveStart, .moveEnd:
                    viewModel.setLoopRegion(region)
                case .none:
                    break
                }
            }
    }

    private func resolveMode(at x: CGFloat, width: CGFloat, duration: TimeInterval) -> DragMode {
        if let loop = viewModel.loopRegion, loop.isUsable {
            let startX = self.x(for: loop.start, width: width, duration: duration)
            let endX = self.x(for: loop.end, width: width, duration: duration)
            if abs(x - startX) <= handleHitWidth { return .moveStart }
            if abs(x - endX) <= handleHitWidth { return .moveEnd }
        }
        return .create(anchorTime: time(forX: x, width: width), startX: x)
    }
}
