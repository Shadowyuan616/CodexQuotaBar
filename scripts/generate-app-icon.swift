import AppKit
import Foundation

struct IconOutput {
    let filename: String
    let pixelSize: Int
}

enum AppIconGeneratorError: Error, CustomStringConvertible {
    case missingArgument(String)
    case bitmapCreationFailed(Int)
    case pngEncodingFailed(Int)
    case invalidICNSType(String)

    var description: String {
        switch self {
        case .missingArgument(let argument):
            return "Missing required argument: \(argument)"
        case .bitmapCreationFailed(let size):
            return "Unable to create \(size)x\(size) bitmap"
        case .pngEncodingFailed(let size):
            return "Unable to encode \(size)x\(size) PNG"
        case .invalidICNSType(let type):
            return "Invalid ICNS chunk type: \(type)"
        }
    }
}

private let outputs = [
    IconOutput(filename: "icon_16x16.png", pixelSize: 16),
    IconOutput(filename: "icon_16x16@2x.png", pixelSize: 32),
    IconOutput(filename: "icon_32x32.png", pixelSize: 32),
    IconOutput(filename: "icon_32x32@2x.png", pixelSize: 64),
    IconOutput(filename: "icon_128x128.png", pixelSize: 128),
    IconOutput(filename: "icon_128x128@2x.png", pixelSize: 256),
    IconOutput(filename: "icon_256x256.png", pixelSize: 256),
    IconOutput(filename: "icon_256x256@2x.png", pixelSize: 512),
    IconOutput(filename: "icon_512x512.png", pixelSize: 512),
    IconOutput(filename: "icon_512x512@2x.png", pixelSize: 1024),
]

private func argumentValue(after flag: String) -> String? {
    guard let index = CommandLine.arguments.firstIndex(of: flag),
          CommandLine.arguments.indices.contains(index + 1) else {
        return nil
    }
    return CommandLine.arguments[index + 1]
}

private func drawIntelligentOrbitIcon(pixelSize: CGFloat) {
    let canvas = NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize)
    let backgroundInset = pixelSize * 0.035
    let backgroundRect = canvas.insetBy(dx: backgroundInset, dy: backgroundInset)
    let backgroundRadius = pixelSize * 0.22
    let backgroundPath = NSBezierPath(
        roundedRect: backgroundRect,
        xRadius: backgroundRadius,
        yRadius: backgroundRadius
    )

    NSGraphicsContext.saveGraphicsState()
    backgroundPath.addClip()
    let backgroundGradient = NSGradient(colors: [
        NSColor(calibratedRed: 0.14, green: 0.22, blue: 0.25, alpha: 1),
        NSColor(calibratedRed: 0.035, green: 0.075, blue: 0.09, alpha: 1),
    ])
    backgroundGradient?.draw(in: backgroundRect, angle: -55)

    let sheenRect = NSRect(
        x: pixelSize * 0.10,
        y: pixelSize * 0.50,
        width: pixelSize * 0.80,
        height: pixelSize * 0.52
    )
    let sheen = NSGradient(
        starting: NSColor(calibratedWhite: 1, alpha: 0.16),
        ending: NSColor(calibratedWhite: 1, alpha: 0)
    )
    sheen?.draw(in: sheenRect, relativeCenterPosition: NSPoint(x: 0, y: 0.5))
    NSGraphicsContext.restoreGraphicsState()

    NSColor(calibratedWhite: 1, alpha: 0.14).setStroke()
    backgroundPath.lineWidth = max(0.75, pixelSize * 0.0025)
    backgroundPath.stroke()

    let center = NSPoint(x: canvas.midX, y: canvas.midY)
    let orbitRect = NSRect(
        x: center.x - pixelSize * 0.29,
        y: center.y - pixelSize * 0.135,
        width: pixelSize * 0.58,
        height: pixelSize * 0.27
    )
    let orbitColor = NSColor(calibratedRed: 0.19, green: 0.91, blue: 0.58, alpha: 1)
    let orbitGlowColor = NSColor(calibratedRed: 0.10, green: 0.72, blue: 0.43, alpha: 0.34)
    let orbitWidth = max(1.25, pixelSize * 0.072)

    for angle in [0.0, 60.0, -60.0] {
        NSGraphicsContext.saveGraphicsState()
        let transform = NSAffineTransform()
        transform.translateX(by: center.x, yBy: center.y)
        transform.rotate(byDegrees: angle)
        transform.translateX(by: -center.x, yBy: -center.y)
        transform.concat()

        let glowPath = NSBezierPath(ovalIn: orbitRect)
        glowPath.lineWidth = orbitWidth * 1.28
        glowPath.lineCapStyle = .round
        orbitGlowColor.setStroke()
        glowPath.stroke()

        let orbitPath = NSBezierPath(ovalIn: orbitRect)
        orbitPath.lineWidth = orbitWidth
        orbitPath.lineCapStyle = .round
        orbitColor.setStroke()
        orbitPath.stroke()
        NSGraphicsContext.restoreGraphicsState()
    }

    let glowSize = pixelSize * 0.24
    let centerGlowRect = NSRect(
        x: center.x - glowSize / 2,
        y: center.y - glowSize / 2,
        width: glowSize,
        height: glowSize
    )
    let centerGlow = NSGradient(
        starting: NSColor(calibratedRed: 0.45, green: 1.0, blue: 0.72, alpha: 0.62),
        ending: NSColor(calibratedRed: 0.20, green: 0.92, blue: 0.57, alpha: 0)
    )
    centerGlow?.draw(in: centerGlowRect, relativeCenterPosition: .zero)

    let centerDotSize = max(2, pixelSize * 0.085)
    let centerDotRect = NSRect(
        x: center.x - centerDotSize / 2,
        y: center.y - centerDotSize / 2,
        width: centerDotSize,
        height: centerDotSize
    )
    NSColor(calibratedRed: 0.78, green: 1.0, blue: 0.88, alpha: 1).setFill()
    NSBezierPath(ovalIn: centerDotRect).fill()
    NSColor(calibratedWhite: 1, alpha: 0.72).setStroke()
    let centerStroke = NSBezierPath(ovalIn: centerDotRect.insetBy(dx: 0.5, dy: 0.5))
    centerStroke.lineWidth = max(0.5, pixelSize * 0.002)
    centerStroke.stroke()
}

private func pngData(pixelSize: Int) throws -> Data {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: pixelSize,
        pixelsHigh: pixelSize,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        throw AppIconGeneratorError.bitmapCreationFailed(pixelSize)
    }

    guard let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
        throw AppIconGeneratorError.bitmapCreationFailed(pixelSize)
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.imageInterpolation = .high
    context.shouldAntialias = true
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: pixelSize, height: pixelSize).fill()
    drawIntelligentOrbitIcon(pixelSize: CGFloat(pixelSize))
    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw AppIconGeneratorError.pngEncodingFailed(pixelSize)
    }
    return data
}

private func appendBigEndian(_ value: UInt32, to data: inout Data) {
    var bigEndianValue = value.bigEndian
    withUnsafeBytes(of: &bigEndianValue) { bytes in
        data.append(contentsOf: bytes)
    }
}

private func icnsChunk(type: String, pngData: Data) throws -> Data {
    guard let typeData = type.data(using: .ascii), typeData.count == 4 else {
        throw AppIconGeneratorError.invalidICNSType(type)
    }

    var chunk = Data()
    chunk.append(typeData)
    appendBigEndian(UInt32(pngData.count + 8), to: &chunk)
    chunk.append(pngData)
    return chunk
}

private func icnsData(pngByPixelSize: [Int: Data]) throws -> Data {
    let entries: [(type: String, pixelSize: Int)] = [
        ("icp4", 16),
        ("icp5", 32),
        ("icp6", 64),
        ("ic07", 128),
        ("ic08", 256),
        ("ic09", 512),
        ("ic10", 1024),
    ]

    var chunks = Data()
    for entry in entries {
        guard let png = pngByPixelSize[entry.pixelSize] else {
            throw AppIconGeneratorError.pngEncodingFailed(entry.pixelSize)
        }
        chunks.append(try icnsChunk(type: entry.type, pngData: png))
    }

    var container = Data("icns".utf8)
    appendBigEndian(UInt32(chunks.count + 8), to: &container)
    container.append(chunks)
    return container
}

private func run() throws {
    guard let outputDirectoryPath = argumentValue(after: "--output-dir") else {
        throw AppIconGeneratorError.missingArgument("--output-dir")
    }
    guard let masterPath = argumentValue(after: "--master") else {
        throw AppIconGeneratorError.missingArgument("--master")
    }
    guard let icnsPath = argumentValue(after: "--icns") else {
        throw AppIconGeneratorError.missingArgument("--icns")
    }

    let fileManager = FileManager.default
    let outputDirectory = URL(fileURLWithPath: outputDirectoryPath, isDirectory: true)
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

    var pngByPixelSize: [Int: Data] = [:]
    for output in outputs {
        let destination = outputDirectory.appendingPathComponent(output.filename)
        let data = try pngData(pixelSize: output.pixelSize)
        pngByPixelSize[output.pixelSize] = data
        try data.write(to: destination, options: .atomic)
    }

    let masterURL = URL(fileURLWithPath: masterPath)
    try fileManager.createDirectory(
        at: masterURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    let masterData = try (pngByPixelSize[1024] ?? pngData(pixelSize: 1024))
    pngByPixelSize[1024] = masterData
    try masterData.write(to: masterURL, options: .atomic)

    let icnsURL = URL(fileURLWithPath: icnsPath)
    try fileManager.createDirectory(
        at: icnsURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try icnsData(pngByPixelSize: pngByPixelSize).write(to: icnsURL, options: .atomic)
}

do {
    try run()
} catch {
    FileHandle.standardError.write(Data("App icon generation failed: \(error)\n".utf8))
    exit(1)
}
