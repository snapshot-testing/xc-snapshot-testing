// Copyright (c) Snapshot Testing
// SPDX-License-Identifier: MIT

#if os(iOS) || os(tvOS) || os(macOS) || os(visionOS)
import Accelerate.vImage
import CoreImage.CIKernel
import MetalPerformanceShaders
@preconcurrency import Metal.MTLDevice

extension CIImage {

    func perceptuallyCompare(
        _ newValue: CIImage,
        pixelPrecision: Float,
        perceptualPrecision: Float,
        usesMetal: Bool? = nil
    ) -> String? {
        // Calculate the deltaE values. Each pixel is a value between 0-100.
        // 0 means no difference, 100 means completely opposite.
        let deltaOutputImage = self.applyingLabDeltaE(newValue)
        // Core Image runs filters in the working color space, and its kernels expect those values to be
        // linear light. Disabling color management (NSNull) leaves gamma-encoded values untouched, so
        // CILabDeltaE treats them as linear and inflates the difference in dark regions: a single 8-bit
        // step at black reports 3.54 instead of 0.27. Ask for a linear working space so the sRGB
        // transfer function is decoded before the delta is computed. The output stays unmanaged because
        // it is a computed value rather than an image to display.
        let context = CIContext(
            options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.extendedLinearSRGB) as Any,
                .outputColorSpace: NSNull(),
            ]
        )
        let deltaThreshold = (1 - perceptualPrecision) * 100

        // Metal is supported by all iOS/tvOS devices (2013 models or later) and Macs (2012 models or later).
        // Older devices do not support iOS/tvOS 13 and macOS 10.15 which are the minimum versions of swift-snapshot-testing.
        // However, some virtualized hardware do not have GPUs and therefore do not support Metal.
        // In this case, macOS falls back to a CPU-based OpenGL ES renderer that silently fails when a Metal command is issued.
        // Other virtualized machines report a Metal device that cannot run the kernel. In both cases the
        // difference is measured on the CPU, by iterating over the pixels of a vImage buffer.
        let metalMeasurement =
            (usesMetal ?? ThresholdImageProcessorKernel.isSupported)
            ? deltaOutputImage.measuringWithMetal(
                deltaThreshold: deltaThreshold,
                pixelPrecision: pixelPrecision,
                in: context
            )
            : nil

        guard
            let measurement = metalMeasurement
                ?? deltaOutputImage.measuringOnCPU(deltaThreshold: deltaThreshold, in: context)
        else {
            return "Newly-taken snapshot's data could not be processed."
        }

        let (actualPixelPrecision, maximumDeltaE) = measurement

        guard actualPixelPrecision < pixelPrecision else { return nil }
        // The actual perceptual precision is the perceptual precision of the pixel with the highest DeltaE.
        // DeltaE is in a 0-100 scale, so we need to divide by 100 to transform it to a percentage.
        let minimumPerceptualPrecision = 1 - min(maximumDeltaE / 100, 1)
        return """
            The percentage of pixels that match \(actualPixelPrecision) is less than required \(pixelPrecision)
            The lowest perceptual color precision \(minimumPerceptualPrecision) is less than required \(perceptualPrecision)
            """
    }
}

extension CIImage {

    /// Measures the share of pixels above the threshold, and the highest delta, with a Metal kernel.
    ///
    /// - Returns: `nil` when the machine cannot run the kernel.
    fileprivate func measuringWithMetal(
        deltaThreshold: Float,
        pixelPrecision: Float,
        in context: CIContext
    ) -> (pixelPrecision: Float, maximumDeltaE: Float)? {
        guard
            let thresholdOutputImage = try? applyingThreshold(deltaThreshold),
            let averagePixel = thresholdOutputImage.applyingAreaAverage().renderSingleValue(in: context)
        else { return nil }

        let actualPixelPrecision = 1 - averagePixel
        var maximumDeltaE: Float = 0

        if actualPixelPrecision < pixelPrecision {
            maximumDeltaE = applyingAreaMaximum().renderSingleValue(in: context) ?? 0
        }

        return (actualPixelPrecision, maximumDeltaE)
    }

    /// Measures the same values by iterating over the pixels of a buffer on the CPU.
    fileprivate func measuringOnCPU(
        deltaThreshold: Float,
        in context: CIContext
    ) -> (pixelPrecision: Float, maximumDeltaE: Float)? {
        guard let buffer = render(in: context) else { return nil }
        defer { buffer.free() }

        var failingPixelCount: Int = 0
        var maximumDeltaE: Float = 0
        // rowBytes must be a multiple of 8, so vImage_Buffer pads the end of each row with bytes to meet the multiple of 0 requirement.
        // We must do 2D iteration of the vImage_Buffer in order to avoid loading the padding garbage bytes at the end of each row.
        //
        // NB: We are purposely using a verbose 'while' loop instead of a 'for in' loop.  When the
        //     compiler doesn't have optimizations enabled, like in test targets, a `while` loop is
        //     significantly faster than a `for` loop for iterating through the elements of a memory
        //     buffer. Details can be found in [SR-6983](https://github.com/apple/swift/issues/49531)
        let componentStride = MemoryLayout<Float>.stride
        var line = 0
        while line < buffer.height {
            defer { line += 1 }
            let lineOffset = buffer.rowBytes * line
            var column = 0
            while column < buffer.width {
                defer { column += 1 }
                let byteOffset = lineOffset + column * componentStride
                let deltaE = buffer.data.load(fromByteOffset: byteOffset, as: Float.self)
                if deltaE > deltaThreshold {
                    failingPixelCount += 1
                    if deltaE > maximumDeltaE {
                        maximumDeltaE = deltaE
                    }
                }
            }
        }

        let failingPixelPercent = Float(failingPixelCount) / Float(extent.width * extent.height)
        return (1 - failingPixelPercent, maximumDeltaE)
    }
}

extension CIImage {

    fileprivate func applyingLabDeltaE(_ other: CIImage) -> CIImage {
        applyingFilter("CILabDeltaE", parameters: ["inputImage2": other])
    }

    fileprivate func applyingThreshold(_ threshold: Float) throws -> CIImage {
        try ThresholdImageProcessorKernel.apply(
            withExtent: extent,
            inputs: [self],
            arguments: [ThresholdImageProcessorKernel.inputThresholdKey: threshold]
        )
    }

    fileprivate func applyingAreaAverage() -> CIImage {
        applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
    }

    fileprivate func applyingAreaMaximum() -> CIImage {
        applyingFilter("CIAreaMaximum", parameters: [kCIInputExtentKey: CIVector(cgRect: extent)])
    }

    fileprivate func renderSingleValue(in context: CIContext) -> Float? {
        guard let buffer = render(in: context) else { return nil }
        defer { buffer.free() }
        return buffer.data.load(fromByteOffset: 0, as: Float.self)
    }

    fileprivate func render(in context: CIContext, format: CIFormat = CIFormat.Rh) -> vImage_Buffer? {
        // Some hardware configurations (virtualized CPU renderers) do not support 32-bit float output formats,
        // so use a compatible 16-bit float format and convert the output value to 32-bit floats.
        guard
            var buffer16 = try? vImage_Buffer(
                width: Int(extent.width),
                height: Int(extent.height),
                bitsPerPixel: 16
            )
        else { return nil }
        defer { buffer16.free() }
        context.render(
            self,
            toBitmap: buffer16.data,
            rowBytes: buffer16.rowBytes,
            bounds: extent,
            format: format,
            colorSpace: nil
        )
        guard
            var buffer32 = try? vImage_Buffer(
                width: Int(buffer16.width),
                height: Int(buffer16.height),
                bitsPerPixel: 32
            ),
            vImageConvert_Planar16FtoPlanarF(&buffer16, &buffer32, 0) == kvImageNoError
        else { return nil }
        return buffer32
    }
}

// Copied from https://developer.apple.com/documentation/coreimage/ciimageprocessorkernel
private final class ThresholdImageProcessorKernel: CIImageProcessorKernel {
    static let inputThresholdKey = "thresholdValue"
    static let device = MTLCreateSystemDefaultDevice()

    static var isSupported: Bool {
        guard let device = device else {
            return false
        }

        return MPSSupportsMTLDevice(device)
    }

    override class func process(
        with inputs: [CIImageProcessorInput]?,
        arguments: [String: Any]?,
        output: CIImageProcessorOutput
    ) throws {
        guard
            let device = device,
            let commandBuffer = output.metalCommandBuffer,
            let input = inputs?.first,
            let sourceTexture = input.metalTexture,
            let destinationTexture = output.metalTexture,
            let thresholdValue = arguments?[inputThresholdKey] as? Float
        else {
            return
        }

        let threshold = MPSImageThresholdBinary(
            device: device,
            thresholdValue: thresholdValue,
            maximumValue: 1.0,
            linearGrayColorTransform: nil
        )

        threshold.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )
    }
}
#endif
