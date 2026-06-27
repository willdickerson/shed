//
//  TuningAnalyzer.swift
//  Shed
//
//  Estimates how far a recording is tuned from standard A440. For every short
//  frame it takes an FFT, finds the strongest spectral peaks, and measures each
//  peak's deviation (in cents) from the nearest equal-tempered frequency. Those
//  deviations are combined with a magnitude-weighted circular mean, which is
//  robust on polyphonic material (the strong partials cluster around the
//  recording's actual tuning). A low circular concentration means the material
//  isn't pitched enough to trust, so we report no estimate rather than guess.
//

import Accelerate
import AVFoundation
import Foundation

nonisolated struct TuningAnalyzer {
    private let frameSize = 4096
    private let hop = 2048
    private let maxDuration: TimeInterval = 120
    private let minFrequency: Double = 55
    private let maxFrequency: Double = 2000
    private let minDetections = 300
    private let minPeakedness = 1.4

    /// Returns an estimate, or `nil` when the recording can't be analyzed
    /// confidently. Throws only when the audio can't be read.
    func analyze(url: URL) async throws -> TuningEstimate? {
        let (samples, sampleRate) = try readMono(url: url)
        guard samples.count >= frameSize, sampleRate > 0 else { return nil }

        let n = frameSize
        let log2n = vDSP_Length(log2(Double(n)).rounded())
        guard let setup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            throw ShedError.waveformFailed("Couldn’t initialize analysis.")
        }
        defer { vDSP_destroy_fftsetup(setup) }

        var window = [Float](repeating: 0, count: n)
        vDSP_hann_window(&window, vDSP_Length(n), Int32(vDSP_HANN_NORM))

        let half = n / 2
        var realp = [Float](repeating: 0, count: half)
        var imagp = [Float](repeating: 0, count: half)
        var windowed = [Float](repeating: 0, count: n)
        var magnitudes = [Float](repeating: 0, count: half)

        let kMin = max(1, Int(minFrequency * Double(n) / sampleRate))
        let kMax = min(half - 2, Int(maxFrequency * Double(n) / sampleRate))
        guard kMax > kMin else { return nil }

        var histogram = [Double](repeating: 0, count: 100) // weighted cents deviations
        var detections = 0
        var start = 0

        while start + n <= samples.count {
            if Task.isCancelled { return nil }

            samples.withUnsafeBufferPointer { sp in
                vDSP_vmul(sp.baseAddress! + start, 1, window, 1, &windowed, 1, vDSP_Length(n))
            }

            realp.withUnsafeMutableBufferPointer { rp in
                imagp.withUnsafeMutableBufferPointer { ip in
                    var split = DSPSplitComplex(realp: rp.baseAddress!, imagp: ip.baseAddress!)
                    windowed.withUnsafeBufferPointer { wp in
                        wp.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: half) { cp in
                            vDSP_ctoz(cp, 2, &split, 1, vDSP_Length(half))
                        }
                    }
                    vDSP_fft_zrip(setup, &split, 1, log2n, FFTDirection(FFT_FORWARD))
                    vDSP_zvmags(&split, 1, &magnitudes, 1, vDSP_Length(half))
                }
            }

            var frameMax: Float = 0
            for k in kMin...kMax where magnitudes[k] > frameMax { frameMax = magnitudes[k] }
            guard frameMax > 1e-6 else { start += hop; continue }
            let threshold = frameMax * 0.02

            for k in kMin...kMax {
                let m = magnitudes[k]
                if m < threshold { continue }
                if m <= magnitudes[k - 1] || m <= magnitudes[k + 1] { continue }

                // Parabolic interpolation for sub-bin frequency precision.
                let a = magnitudes[k - 1], b = m, c = magnitudes[k + 1]
                let denom = a - 2 * b + c
                let delta = denom != 0 ? 0.5 * (a - c) / denom : 0
                let freq = (Double(k) + Double(delta)) * sampleRate / Double(n)
                guard freq >= minFrequency, freq <= maxFrequency else { continue }

                let midi = 69 + 12 * log2(freq / 440)
                let centsDeviation = (midi - midi.rounded()) * 100   // (-50, 50]
                let weight = Double(m.squareRoot())                  // amplitude
                let bin = ((Int(centsDeviation.rounded()) % 100) + 100) % 100
                histogram[bin] += weight
                detections += 1
            }
            start += hop
        }

        guard detections >= minDetections else { return nil }

        // Circularly smooth the cents histogram and take its mode. The mode is
        // robust to the spread harmonics add — fundamentals and octaves pile up
        // at the true offset while upper partials scatter thinly.
        var smoothed = [Double](repeating: 0, count: 100)
        for b in 0..<100 {
            var sum = 0.0
            for j in -3...3 { sum += histogram[((b + j) % 100 + 100) % 100] }
            smoothed[b] = sum
        }
        let total = smoothed.reduce(0, +)
        guard total > 0 else { return nil }
        let mean = total / 100

        var peakBin = 0
        for b in 1..<100 where smoothed[b] > smoothed[peakBin] { peakBin = b }
        guard smoothed[peakBin] / mean >= minPeakedness else { return nil }

        let offset = peakBin <= 50 ? Double(peakBin) : Double(peakBin - 100)
        return TuningEstimate(offsetCents: offset, detectionCount: detections)
    }

    // MARK: - Reading

    private func readMono(url: URL) throws -> ([Float], Double) {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let sampleRate = format.sampleRate
            let total = file.length
            guard total > 0, sampleRate > 0 else { return ([], sampleRate) }

            let cap = Int(min(Double(total), maxDuration * sampleRate))
            var samples = [Float]()
            samples.reserveCapacity(cap)

            let block: AVAudioFrameCount = 1 << 16
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: block) else {
                throw ShedError.waveformFailed("Couldn’t allocate an analysis buffer.")
            }

            while samples.count < cap {
                try file.read(into: buffer)
                let length = Int(buffer.frameLength)
                guard length > 0, let channel = buffer.floatChannelData else { break }
                let data = channel[0]
                for i in 0..<length {
                    samples.append(data[i])
                    if samples.count >= cap { break }
                }
            }
            return (samples, sampleRate)
        } catch let error as ShedError {
            throw error
        } catch {
            throw ShedError.waveformFailed(error.localizedDescription)
        }
    }
}
