import AVFoundation
import CoreVideo
import Foundation
import UIKit

enum SnapshotVideoRecorder {
    static func record(
        plan: VideoCapturePlan,
        frameProvider: @escaping () async throws -> Data
    ) async throws -> URL {
        let outputURL = try outputURL(for: plan.filename)
        try? FileManager.default.removeItem(at: outputURL)

        let firstFrameData = try await frameProvider()
        guard let firstImage = UIImage(data: firstFrameData),
              let firstCGImage = firstImage.cgImage else {
            throw OpenFlexureClientError.videoWriterFailed("The snapshot stream did not return a valid image.")
        }

        let width = firstCGImage.width
        let height = firstCGImage.height

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerBox = WriterBox(writer)
        let input = AVAssetWriterInput(
            mediaType: .video,
            outputSettings: [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
        )
        input.expectsMediaDataInRealTime = false

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input,
            sourcePixelBufferAttributes: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
        )

        guard writer.canAdd(input) else {
            throw OpenFlexureClientError.videoWriterFailed("The MP4 writer could not accept the video input.")
        }

        writer.add(input)

        guard writer.startWriting() else {
            throw OpenFlexureClientError.videoWriterFailed(writer.error?.localizedDescription ?? "Failed to start writing.")
        }

        writer.startSession(atSourceTime: .zero)

        let frameCount = max(1, plan.durationSeconds * plan.framesPerSecond)
        let frameDuration = CMTime(value: 1, timescale: CMTimeScale(plan.framesPerSecond))
        let frameIntervalNanoseconds = UInt64(1_000_000_000 / max(1, plan.framesPerSecond))

        for frameIndex in 0..<frameCount {
            let frameData = frameIndex == 0 ? firstFrameData : try await frameProvider()
            guard let image = UIImage(data: frameData) else {
                throw OpenFlexureClientError.videoWriterFailed("A recorded frame was not valid image data.")
            }

            while !input.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            let presentationTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
            let pixelBuffer = try makePixelBuffer(
                from: image,
                width: width,
                height: height,
                pool: adaptor.pixelBufferPool
            )

            guard adaptor.append(pixelBuffer, withPresentationTime: presentationTime) else {
                throw OpenFlexureClientError.videoWriterFailed(writer.error?.localizedDescription ?? "Could not append frame \(frameIndex).")
            }

            if frameIndex < frameCount - 1 {
                try await Task.sleep(nanoseconds: frameIntervalNanoseconds)
            }
        }

        input.markAsFinished()

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerBox.writer.finishWriting {
                if let error = writerBox.writer.error {
                    continuation.resume(throwing: OpenFlexureClientError.videoWriterFailed(error.localizedDescription))
                } else {
                    continuation.resume(returning: ())
                }
            }
        }

        return outputURL
    }

    private static func outputURL(for filename: String) throws -> URL {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw OpenFlexureClientError.videoWriterFailed("The app documents directory is unavailable.")
        }
        let stem = sanitizedFilenameStem(filename, fallback: "openflux_video")
        return documentsDirectory.appendingPathComponent(stem).appendingPathExtension("mp4")
    }

    private static func sanitizedFilenameStem(_ raw: String, fallback: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleanedScalars = raw.unicodeScalars.map { allowed.contains($0) ? Character($0) : "_" }
        let cleaned = String(cleanedScalars).trimmingCharacters(in: CharacterSet(charactersIn: "_"))
        return cleaned.isEmpty ? fallback : cleaned
    }

    private static func makePixelBuffer(
        from image: UIImage,
        width: Int,
        height: Int,
        pool: CVPixelBufferPool?
    ) throws -> CVPixelBuffer {
        var maybeBuffer: CVPixelBuffer?

        let createStatus: CVReturn
        if let pool {
            createStatus = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &maybeBuffer)
        } else {
            createStatus = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32ARGB,
                nil,
                &maybeBuffer
            )
        }

        guard createStatus == kCVReturnSuccess, let pixelBuffer = maybeBuffer else {
            throw OpenFlexureClientError.videoWriterFailed("Could not allocate a pixel buffer for the video frame.")
        }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(pixelBuffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            throw OpenFlexureClientError.videoWriterFailed("Could not create a drawing context for the video frame.")
        }

        context.clear(CGRect(x: 0, y: 0, width: width, height: height))
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        if let cgImage = image.cgImage {
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        } else {
            throw OpenFlexureClientError.videoWriterFailed("Could not read image pixels for the video frame.")
        }

        return pixelBuffer
    }

    private final class WriterBox: @unchecked Sendable {
        let writer: AVAssetWriter

        init(_ writer: AVAssetWriter) {
            self.writer = writer
        }
    }
}
