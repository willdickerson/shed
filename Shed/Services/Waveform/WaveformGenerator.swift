//
//  WaveformGenerator.swift
//  Shed
//
//  Reads a WAV file and downsamples it into min/max peak buckets. Runs off the
//  main actor and reads in blocks so long files stay memory-friendly.
//

import AVFoundation
import Foundation

nonisolated struct WaveformGenerator {
    /// Number of buckets to produce. The renderer aggregates further to the
    /// pixel width, so this just needs to be high enough for good resolution.
    let targetBuckets: Int

    init(targetBuckets: Int = 4000) {
        self.targetBuckets = targetBuckets
    }

    nonisolated func generate(from url: URL) async throws -> WaveformData {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let totalFrames = file.length
            let sampleRate = format.sampleRate
            guard totalFrames > 0, sampleRate > 0 else {
                throw ShedError.waveformFailed("The audio file appears to be empty.")
            }

            let bucketCount = min(targetBuckets, Int(totalFrames))
            let framesPerBucket = max(1, Int(totalFrames) / bucketCount)

            var mins = [Float]()
            var maxs = [Float]()
            mins.reserveCapacity(bucketCount)
            maxs.reserveCapacity(bucketCount)

            var peak: Float = 0
            var bucketMin: Float = .greatestFiniteMagnitude
            var bucketMax: Float = -.greatestFiniteMagnitude
            var framesInBucket = 0

            let blockSize: AVAudioFrameCount = 1 << 16
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: blockSize) else {
                throw ShedError.waveformFailed("Couldn’t allocate a read buffer.")
            }

            while file.framePosition < totalFrames {
                try file.read(into: buffer)
                let frameLength = Int(buffer.frameLength)
                guard frameLength > 0, let channelData = buffer.floatChannelData else { break }

                let samples = channelData[0] // first channel is representative enough
                for i in 0..<frameLength {
                    let value = samples[i]
                    if value < bucketMin { bucketMin = value }
                    if value > bucketMax { bucketMax = value }
                    let magnitude = abs(value)
                    if magnitude > peak { peak = magnitude }

                    framesInBucket += 1
                    if framesInBucket >= framesPerBucket {
                        mins.append(bucketMin)
                        maxs.append(bucketMax)
                        bucketMin = .greatestFiniteMagnitude
                        bucketMax = -.greatestFiniteMagnitude
                        framesInBucket = 0
                    }
                }
            }

            // Flush any trailing partial bucket.
            if framesInBucket > 0 {
                mins.append(bucketMin)
                maxs.append(bucketMax)
            }

            let duration = Double(totalFrames) / sampleRate
            return WaveformData(mins: mins, maxs: maxs, peak: peak > 0 ? peak : 1, duration: duration)
        } catch let error as ShedError {
            throw error
        } catch {
            throw ShedError.waveformFailed(error.localizedDescription)
        }
    }
}
