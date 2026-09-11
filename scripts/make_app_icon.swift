#!/usr/bin/env swift
import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

let outputDir = URL(fileURLWithPath: "/Users/tejastelkar/Desktop/sidedeck/Resources/SideDeck.iconset")
try? FileManager.default.removeItem(at: outputDir)
try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

func renderIcon(size: Int) -> CGImage? {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    guard let ctx = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: size * 4,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { return nil }
    
    let scale = CGFloat(size) / 1024.0
    ctx.scaleBy(x: scale, y: scale)
    
    // Background Squircle
    let squircleRect = CGRect(x: 72, y: 72, width: 880, height: 880)
    let squirclePath = CGPath(roundedRect: squircleRect, cornerWidth: 200, cornerHeight: 200, transform: nil)
    
    // Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: CGColor(gray: 0, alpha: 0.5))
    ctx.addPath(squirclePath)
    ctx.setFillColor(CGColor(red: 0.05, green: 0.06, blue: 0.09, alpha: 1.0))
    ctx.fillPath()
    ctx.restoreGState()
    
    // Clip squircle
    ctx.saveGState()
    ctx.addPath(squirclePath)
    ctx.clip()
    
    // Base Gradient
    let baseGradColors = [
        CGColor(red: 0.10, green: 0.12, blue: 0.18, alpha: 1.0),
        CGColor(red: 0.04, green: 0.05, blue: 0.08, alpha: 1.0)
    ] as CFArray
    let baseGrad = CGGradient(colorsSpace: colorSpace, colors: baseGradColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(baseGrad, start: CGPoint(x: 512, y: 952), end: CGPoint(x: 512, y: 72), options: [])
    
    // Subtle backdrop grid / desktop preview
    ctx.setStrokeColor(CGColor(red: 0.25, green: 0.35, blue: 0.55, alpha: 0.12))
    ctx.setLineWidth(2)
    for x in stride(from: 140, to: 880, by: 70) {
        ctx.move(to: CGPoint(x: CGFloat(x), y: 72))
        ctx.addLine(to: CGPoint(x: CGFloat(x), y: 952))
    }
    for y in stride(from: 140, to: 952, by: 70) {
        ctx.move(to: CGPoint(x: 72, y: CGFloat(y)))
        ctx.addLine(to: CGPoint(x: 952, y: CGFloat(y)))
    }
    ctx.strokePath()
    
    // Radial ambient glow from top-right
    let glowColors = [
        CGColor(red: 0.2, green: 0.6, blue: 1.0, alpha: 0.35),
        CGColor(red: 0.0, green: 0.8, blue: 0.7, alpha: 0.0)
    ] as CFArray
    let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
    ctx.drawRadialGradient(glowGrad, startCenter: CGPoint(x: 720, y: 720), startRadius: 10, endCenter: CGPoint(x: 720, y: 720), endRadius: 460, options: [])
    
    // The Floating SideDock Panel representation
    let dockRect = CGRect(x: 580, y: 150, width: 270, height: 724)
    let dockPath = CGPath(roundedRect: dockRect, cornerWidth: 44, cornerHeight: 44, transform: nil)
    
    // Dock Outer Shadow
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: -12, height: 0), blur: 36, color: CGColor(gray: 0, alpha: 0.6))
    ctx.addPath(dockPath)
    ctx.setFillColor(CGColor(red: 0.08, green: 0.10, blue: 0.15, alpha: 0.95))
    ctx.fillPath()
    ctx.restoreGState()
    
    // Dock Fill with Frosted Glass look
    ctx.saveGState()
    ctx.addPath(dockPath)
    ctx.clip()
    
    let dockGradColors = [
        CGColor(red: 0.16, green: 0.20, blue: 0.28, alpha: 0.9),
        CGColor(red: 0.08, green: 0.10, blue: 0.14, alpha: 0.95)
    ] as CFArray
    let dockGrad = CGGradient(colorsSpace: colorSpace, colors: dockGradColors, locations: [0.0, 1.0])!
    ctx.drawLinearGradient(dockGrad, start: CGPoint(x: 715, y: 874), end: CGPoint(x: 715, y: 150), options: [])
    
    // Micro Widget 1: Focus Progress Ring
    let ringCenter = CGPoint(x: 715, y: 750)
    let ringRadius: CGFloat = 58
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.1))
    ctx.setLineWidth(10)
    ctx.addArc(center: ringCenter, radius: ringRadius, startAngle: 0, endAngle: .pi * 2, clockwise: false)
    ctx.strokePath()
    
    // Progress Arc (Cyan to Emerald)
    ctx.setStrokeColor(CGColor(red: 0.18, green: 0.86, blue: 0.76, alpha: 1.0))
    ctx.setLineWidth(10)
    ctx.setLineCap(.round)
    ctx.addArc(center: ringCenter, radius: ringRadius, startAngle: -.pi / 2, endAngle: .pi * 0.8, clockwise: false)
    ctx.strokePath()
    
    // Center ring dot
    ctx.setFillColor(CGColor(red: 0.18, green: 0.86, blue: 0.76, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: ringCenter.x - 6, y: ringCenter.y - 6, width: 12, height: 12))
    
    // Micro Widget 2: Clock & Status bars
    let pillRect = CGRect(x: 620, y: 610, width: 190, height: 38)
    let pillPath = CGPath(roundedRect: pillRect, cornerWidth: 12, cornerHeight: 12, transform: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.08))
    ctx.addPath(pillPath)
    ctx.fillPath()
    
    // Green power indicator dot
    ctx.setFillColor(CGColor(red: 0.2, green: 0.85, blue: 0.45, alpha: 1.0))
    ctx.fillEllipse(in: CGRect(x: 636, y: 623, width: 12, height: 12))
    
    // Status text dashes
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.7))
    ctx.fill(CGRect(x: 660, y: 626, width: 80, height: 6))
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.35))
    ctx.fill(CGRect(x: 750, y: 626, width: 44, height: 6))
    
    // Micro Widget 3: 4x4 Habit Matrix Dots
    let matrixOriginX: CGFloat = 638
    let matrixOriginY: CGFloat = 460
    for row in 0..<4 {
        for col in 0..<5 {
            let dotX = matrixOriginX + CGFloat(col) * 32
            let dotY = matrixOriginY + CGFloat(row) * 30
            let isLit = (row + col) % 3 != 0
            if isLit {
                ctx.setFillColor(CGColor(red: 0.15, green: 0.75, blue: 0.95, alpha: CGFloat.random(in: 0.65...1.0)))
            } else {
                ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.1))
            }
            let dotPath = CGPath(roundedRect: CGRect(x: dotX, y: dotY, width: 22, height: 20), cornerWidth: 6, cornerHeight: 6, transform: nil)
            ctx.addPath(dotPath)
            ctx.fillPath()
        }
    }
    
    // Micro Widget 4: Hydration Slosh Wave
    let cupRect = CGRect(x: 630, y: 260, width: 170, height: 140)
    let cupPath = CGPath(roundedRect: cupRect, cornerWidth: 20, cornerHeight: 20, transform: nil)
    ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.06))
    ctx.addPath(cupPath)
    ctx.fillPath()
    
    ctx.saveGState()
    ctx.addPath(cupPath)
    ctx.clip()
    
    // Wave inside cup
    let wavePath = CGMutablePath()
    wavePath.move(to: CGPoint(x: 630, y: 260))
    wavePath.addLine(to: CGPoint(x: 630, y: 340))
    wavePath.addCurve(to: CGPoint(x: 715, y: 355), control1: CGPoint(x: 670, y: 370), control2: CGPoint(x: 685, y: 330))
    wavePath.addCurve(to: CGPoint(x: 800, y: 340), control1: CGPoint(x: 745, y: 380), control2: CGPoint(x: 770, y: 320))
    wavePath.addLine(to: CGPoint(x: 800, y: 260))
    wavePath.closeSubpath()
    
    let waterColors = [
        CGColor(red: 0.05, green: 0.65, blue: 0.98, alpha: 0.85),
        CGColor(red: 0.02, green: 0.40, blue: 0.85, alpha: 0.9)
    ] as CFArray
    let waterGrad = CGGradient(colorsSpace: colorSpace, colors: waterColors, locations: [0.0, 1.0])!
    ctx.addPath(wavePath)
    ctx.clip()
    ctx.drawLinearGradient(waterGrad, start: CGPoint(x: 715, y: 370), end: CGPoint(x: 715, y: 260), options: [])
    ctx.restoreGState()
    
    ctx.restoreGState() // end dock clip
    
    // Dock border stroke
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.22))
    ctx.setLineWidth(2.5)
    ctx.addPath(dockPath)
    ctx.strokePath()
    
    // Squircle Border highlight
    ctx.restoreGState() // end squircle clip
    
    ctx.saveGState()
    ctx.setStrokeColor(CGColor(red: 1, green: 1, blue: 1, alpha: 0.16))
    ctx.setLineWidth(3)
    ctx.addPath(squirclePath)
    ctx.strokePath()
    ctx.restoreGState()
    
    return ctx.makeImage()
}

func saveImage(_ image: CGImage, to url: URL) {
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
}

let sizes = [16, 32, 64, 128, 256, 512, 1024]
for s in sizes {
    if let img = renderIcon(size: s) {
        let fileURL = outputDir.appendingPathComponent("icon_\(s)x\(s).png")
        saveImage(img, to: fileURL)
        if s <= 512 {
            let at2xURL = outputDir.appendingPathComponent("icon_\(s)x\(s)@2x.png")
            if let img2x = renderIcon(size: s * 2) {
                saveImage(img2x, to: at2xURL)
            }
        }
    }
}

// Master preview
if let master = renderIcon(size: 512) {
    let previewURL = URL(fileURLWithPath: "/Users/tejastelkar/Desktop/Software Projects/portfolio/public/assets/sidedeck-icon.png")
    saveImage(master, to: previewURL)
    let logoURL = URL(fileURLWithPath: "/Users/tejastelkar/Desktop/Software Projects/portfolio/public/assets/sidedeck-logo.png")
    if let logo = renderIcon(size: 128) {
        saveImage(logo, to: logoURL)
    }
}

print("Icon set successfully created.")
