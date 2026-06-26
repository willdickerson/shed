//
//  WaveformView.swift
//  Shed
//
//  The primary interaction surface. The waveform itself is drawn in a Canvas;
//  the playhead and loop region are SwiftUI overlays so they animate natively
//  and the loop can fade in. Coordinates map through the current Viewport.
//

import AppKit
import SwiftUI

struct WaveformView: View {
    @Bindable var viewModel: WorkspaceViewModel
    let waveform: WaveformData
    @Binding var viewport: Viewport
    let onInteract: () -> Void

    @State private var dragMode: DragMode?
    @State private var previewLoop: LoopRegion?
    @State private var hoveredHandle: HandleSide?

    private let handleHitWidth: CGFloat = 10
    private let topInset: CGFloat = 24

    private enum DragMode: Equatable {
        case create(anchorTime: TimeInterval, startX: CGFloat)
        case moveStart
        case moveEnd
    }

    private enum HandleSide: Equatable { case start, end }

    var body: some View {
        GeometryReader { geometry in
            let size = geometry.size
            let total = max(viewModel.duration, 0.0001)
            let visibleStart = viewport.clampedStart(total: total)
            let visibleDuration = viewport.visibleDuration(total: total)
            let loop = previewLoop ?? viewModel.loopRegion

            ZStack(alignment: .topLeading) {
                Canvas { context, _ in
                    drawWaveform(in: &context, size: size,
                                 visibleStart: visibleStart, visibleDuration: visibleDuration)
                }

                if let loop, loop.isUsable {
                    loopOverlay(loop, size: size,
                                visibleStart: visibleStart, visibleDuration: visibleDuration)
                }

                playhead(size: size, visibleStart: visibleStart, visibleDuration: visibleDuration)
            }
            .contentShape(Rectangle())
            .gesture(dragGesture(size: size, total: total,
                                 visibleStart: visibleStart, visibleDuration: visibleDuration))
            .onContinuousHover { phase in
                updateHover(phase, width: size.width,
                            visibleStart: visibleStart, visibleDuration: visibleDuration)
            }
            .animation(.easeInOut(duration: 0.2), value: viewModel.loopRegion)
            .onChange(of: viewport.zoom) { _, _ in
                viewport.center(on: viewModel.currentTime, total: total)
            }
            .onChange(of: viewModel.currentTime) { _, time in
                followPlayhead(time, total: total)
            }
        }
    }

    // MARK: - Waveform

    private func drawWaveform(in context: inout GraphicsContext, size: CGSize,
                              visibleStart: TimeInterval, visibleDuration: TimeInterval) {
        let mid = topInset + (size.height - topInset) / 2
        let amplitudeScale = (size.height - topInset) / 2 - 6
        let total = max(viewModel.duration, 0.0001)
        let bucketCount = waveform.bucketCount
        guard bucketCount > 0, amplitudeScale > 0 else { return }

        let peak = CGFloat(waveform.peak)
        let columns = max(1, Int(size.width))
        var path = Path()

        for column in 0..<columns {
            let t0 = visibleStart + Double(column) / Double(columns) * visibleDuration
            let t1 = visibleStart + Double(column + 1) / Double(columns) * visibleDuration
            let b0 = max(0, min(bucketCount - 1, Int(t0 / total * Double(bucketCount))))
            let b1 = max(b0 + 1, min(bucketCount, Int(t1 / total * Double(bucketCount))))

            var minVal: Float = 0
            var maxVal: Float = 0
            for bucket in b0..<b1 {
                minVal = min(minVal, waveform.mins[bucket])
                maxVal = max(maxVal, waveform.maxs[bucket])
            }

            let x = CGFloat(column)
            let topY = mid - (CGFloat(maxVal) / peak) * amplitudeScale
            let bottomY = mid - (CGFloat(minVal) / peak) * amplitudeScale
            path.move(to: CGPoint(x: x, y: topY))
            path.addLine(to: CGPoint(x: x, y: bottomY))
        }
        // Higher-contrast fill so the waveform reads as the focal point.
        context.stroke(path, with: .color(Color(nsColor: .secondaryLabelColor)), lineWidth: 1)

        var baseline = Path()
        baseline.move(to: CGPoint(x: 0, y: mid))
        baseline.addLine(to: CGPoint(x: size.width, y: mid))
        context.stroke(baseline, with: .color(Color(nsColor: .separatorColor)), lineWidth: 0.5)
    }

    // MARK: - Overlays

    private func loopOverlay(_ loop: LoopRegion, size: CGSize,
                             visibleStart: TimeInterval, visibleDuration: TimeInterval) -> some View {
        let width = size.width
        let rawStart = x(for: loop.start, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
        let rawEnd = x(for: loop.end, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
        let startX = min(max(0, rawStart), width)
        let endX = min(max(0, rawEnd), width)
        let bodyHeight = size.height - topInset

        return ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 7)
                .fill(Color.blue.opacity(0.13))
                .overlay(
                    RoundedRectangle(cornerRadius: 7)
                        .strokeBorder(Color.blue.opacity(0.5), lineWidth: 1)
                )
                .frame(width: max(1, endX - startX), height: bodyHeight)
                .position(x: (startX + endX) / 2, y: topInset + bodyHeight / 2)

            if rawStart >= 0, rawStart <= width {
                loopHandle(height: bodyHeight, highlighted: hoveredHandle == .start || dragMode == .moveStart)
                    .position(x: startX, y: topInset + bodyHeight / 2)
                TimeTag(text: TimeFormatting.precise(loop.start), color: .blue)
                    .position(x: startX, y: topInset / 2)
            }
            if rawEnd >= 0, rawEnd <= width {
                loopHandle(height: bodyHeight, highlighted: hoveredHandle == .end || dragMode == .moveEnd)
                    .position(x: endX, y: topInset + bodyHeight / 2)
                TimeTag(text: TimeFormatting.precise(loop.end), color: .blue)
                    .position(x: endX, y: topInset / 2)
            }
        }
        .transition(.opacity)
    }

    private func loopHandle(height: CGFloat, highlighted: Bool) -> some View {
        let width: CGFloat = highlighted ? 8 : 5
        return RoundedRectangle(cornerRadius: width / 2)
            .fill(Color.blue)
            .frame(width: width, height: height)
            .overlay(
                VStack(spacing: 2.5) {
                    ForEach(0..<2, id: \.self) { _ in
                        Capsule().frame(width: 1.5, height: 8)
                    }
                }
                .foregroundStyle(.white.opacity(0.9))
                .opacity(highlighted ? 1 : 0.75)
            )
            .shadow(color: .black.opacity(highlighted ? 0.18 : 0), radius: 3, y: 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: highlighted)
    }

    @ViewBuilder
    private func playhead(size: CGSize, visibleStart: TimeInterval, visibleDuration: TimeInterval) -> some View {
        let px = x(for: viewModel.currentTime, width: size.width,
                   visibleStart: visibleStart, visibleDuration: visibleDuration)
        if px >= 0, px <= size.width {
            let bodyHeight = size.height - topInset
            ZStack(alignment: .topLeading) {
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2, height: bodyHeight)
                    .position(x: px, y: topInset + bodyHeight / 2)
                TimeTag(text: TimeFormatting.precise(viewModel.currentTime), color: .red)
                    .position(x: px, y: topInset / 2)
            }
            // Slight overlap between samples keeps motion continuous.
            .animation(.linear(duration: 0.05), value: viewModel.currentTime)
        }
    }

    // MARK: - Geometry

    private func x(for time: TimeInterval, width: CGFloat,
                   visibleStart: TimeInterval, visibleDuration: TimeInterval) -> CGFloat {
        guard visibleDuration > 0 else { return 0 }
        return CGFloat((time - visibleStart) / visibleDuration) * width
    }

    private func time(forX x: CGFloat, width: CGFloat,
                      visibleStart: TimeInterval, visibleDuration: TimeInterval) -> TimeInterval {
        let fraction = max(0, min(1, x / max(width, 1)))
        return visibleStart + Double(fraction) * visibleDuration
    }

    /// Highlights a loop handle and shows a resize cursor when the pointer is
    /// near it, making the handles feel grabbable.
    private func updateHover(_ phase: HoverPhase, width: CGFloat,
                             visibleStart: TimeInterval, visibleDuration: TimeInterval) {
        guard case let .active(location) = phase,
              let loop = viewModel.loopRegion, loop.isUsable else {
            if hoveredHandle != nil { hoveredHandle = nil }
            if dragMode == nil { NSCursor.arrow.set() }
            return
        }

        let startX = x(for: loop.start, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
        let endX = x(for: loop.end, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
        let side: HandleSide? = abs(location.x - startX) <= handleHitWidth ? .start
            : (abs(location.x - endX) <= handleHitWidth ? .end : nil)

        if side != hoveredHandle { hoveredHandle = side }
        if side != nil { NSCursor.resizeLeftRight.set() } else { NSCursor.arrow.set() }
    }

    private func followPlayhead(_ time: TimeInterval, total: TimeInterval) {
        guard viewport.zoom > 1, viewModel.isPlaying else { return }
        let visibleStart = viewport.clampedStart(total: total)
        let visibleDuration = viewport.visibleDuration(total: total)
        if time < visibleStart || time > visibleStart + visibleDuration {
            viewport.start = min(max(0, time - visibleDuration * 0.2), max(0, total - visibleDuration))
        }
    }

    // MARK: - Gesture

    private func dragGesture(size: CGSize, total: TimeInterval,
                             visibleStart: TimeInterval, visibleDuration: TimeInterval) -> some Gesture {
        let width = size.width
        func t(_ x: CGFloat) -> TimeInterval {
            time(forX: x, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
        }

        return DragGesture(minimumDistance: 0)
            .onChanged { value in
                if dragMode == nil {
                    onInteract()
                    dragMode = resolveMode(at: value.startLocation.x, width: width,
                                           visibleStart: visibleStart, visibleDuration: visibleDuration)
                }
                guard let mode = dragMode else { return }
                switch mode {
                case let .create(anchorTime, _):
                    previewLoop = LoopRegion(start: anchorTime, end: t(value.location.x))
                case .moveStart:
                    let end = viewModel.loopRegion?.end ?? viewModel.duration
                    previewLoop = LoopRegion(start: t(value.location.x), end: end)
                case .moveEnd:
                    let start = viewModel.loopRegion?.start ?? 0
                    previewLoop = LoopRegion(start: start, end: t(value.location.x))
                }
            }
            .onEnded { value in
                let mode = dragMode
                let region = previewLoop
                dragMode = nil
                previewLoop = nil

                if case let .create(_, startX)? = mode, abs(value.location.x - startX) < 4 {
                    viewModel.handleWaveformClick(at: t(value.location.x))
                    return
                }
                guard let region, region.isUsable else { return }
                switch mode {
                case .create: viewModel.createLoop(region)
                case .moveStart, .moveEnd: viewModel.setLoopRegion(region)
                case .none: break
                }
            }
    }

    private func resolveMode(at x: CGFloat, width: CGFloat,
                             visibleStart: TimeInterval, visibleDuration: TimeInterval) -> DragMode {
        if let loop = viewModel.loopRegion, loop.isUsable {
            let startX = self.x(for: loop.start, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
            let endX = self.x(for: loop.end, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration)
            if abs(x - startX) <= handleHitWidth { return .moveStart }
            if abs(x - endX) <= handleHitWidth { return .moveEnd }
        }
        return .create(anchorTime: time(forX: x, width: width, visibleStart: visibleStart, visibleDuration: visibleDuration), startX: x)
    }
}

/// Small rounded timestamp tag floating above the playhead or loop handles.
private struct TimeTag: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: RoundedRectangle(cornerRadius: 4))
            .fixedSize()
    }
}
