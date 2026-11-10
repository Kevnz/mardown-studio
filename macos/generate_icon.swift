import Cocoa
import CoreGraphics

// Generates a 1024x1024 macOS application icon representing Markdown Studio:
// - Left pane: Dark code editor with `#` Markdown header, `M↓` badge, and syntax lines
// - Right pane: Live rendered preview with a glowing Mermaid flowchart diagram & GFM checklist
// - Center: Tactile macOS split-view divider with grab pill

let outputPath = CommandLine.arguments.count > 1
    ? CommandLine.arguments[1]
    : "macos/AppIcon-1024.png"

let size: CGFloat = 1024
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

guard let ctx = CGContext(
    data: nil,
    width: Int(size),
    height: Int(size),
    bitsPerComponent: 8,
    bytesPerRow: 0,
    space: colorSpace,
    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
) else {
    fatalError("Failed to create CGContext")
}

// Helper to create CGColor from hex
func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1.0) -> CGColor {
    return CGColor(srgbRed: r / 255.0, green: g / 255.0, blue: b / 255.0, alpha: a)
}

// Helper for continuous-style rounded rect path
func roundedRectPath(_ rect: CGRect, radius: CGFloat) -> CGPath {
    return CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

// 1. macOS Big Sur / Sonoma Icon Canvas Dimensions (824x824 centered at 100,100 with drop shadow)
let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let cornerRadius: CGFloat = 185

// Outer Drop Shadow
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -24), blur: 48, color: rgba(0, 0, 0, 0.42))
ctx.addPath(roundedRectPath(iconRect, radius: cornerRadius))
ctx.setFillColor(rgba(19, 22, 29))
ctx.fillPath()
ctx.restoreGState()

// Clip to main squircle
let mainSquircle = roundedRectPath(iconRect, radius: cornerRadius)
ctx.saveGState()
ctx.addPath(mainSquircle)
ctx.clip()

// 2. Left Pane Background (Deep Midnight Code Editor)
let splitX: CGFloat = 512
let leftRect = CGRect(x: iconRect.minX, y: iconRect.minY, width: splitX - iconRect.minX, height: iconRect.height)
let leftGradColors = [rgba(26, 31, 44), rgba(15, 18, 26)] as CFArray
let leftGrad = CGGradient(colorsSpace: colorSpace, colors: leftGradColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(
    leftGrad,
    start: CGPoint(x: leftRect.midX, y: leftRect.maxY),
    end: CGPoint(x: leftRect.midX, y: leftRect.minY),
    options: []
)

// 3. Right Pane Background (Rich Indigo-Slate Preview Surface)
let rightRect = CGRect(x: splitX, y: iconRect.minY, width: iconRect.maxX - splitX, height: iconRect.height)
let rightGradColors = [rgba(32, 41, 64), rgba(19, 25, 40)] as CFArray
let rightGrad = CGGradient(colorsSpace: colorSpace, colors: rightGradColors, locations: [0.0, 1.0])!
ctx.drawLinearGradient(
    rightGrad,
    start: CGPoint(x: rightRect.midX, y: rightRect.maxY),
    end: CGPoint(x: rightRect.midX, y: rightRect.minY),
    options: []
)

// Subtle radial glow on the right preview pane behind the Mermaid diagram
let glowColors = [rgba(14, 165, 233, 0.25), rgba(14, 165, 233, 0.0)] as CFArray
let glowGrad = CGGradient(colorsSpace: colorSpace, colors: glowColors, locations: [0.0, 1.0])!
ctx.drawRadialGradient(
    glowGrad,
    startCenter: CGPoint(x: 715, y: 490),
    startRadius: 0,
    endCenter: CGPoint(x: 715, y: 490),
    endRadius: 270,
    options: [.drawsBeforeStartLocation]
)

// 4. Unified macOS Window Titlebar & Traffic Lights
let titlebarHeight: CGFloat = 106
let titlebarRect = CGRect(
    x: iconRect.minX,
    y: iconRect.maxY - titlebarHeight,
    width: iconRect.width,
    height: titlebarHeight
)
ctx.setFillColor(rgba(36, 42, 56, 0.92))
ctx.fill(titlebarRect)

// Titlebar bottom separator line
ctx.setFillColor(rgba(255, 255, 255, 0.10))
ctx.fill(CGRect(x: iconRect.minX, y: titlebarRect.minY, width: iconRect.width, height: 3))

// macOS Traffic Light Dots
let dotY = titlebarRect.midY - 8
let dotRadius: CGFloat = 13.5
let trafficLights: [(CGFloat, CGColor)] = [
    (205, rgba(255, 95, 86)),   // Close Red
    (249, rgba(255, 189, 46)),  // Minimize Yellow
    (293, rgba(39, 201, 63))    // Zoom Green
]
for (cx, color) in trafficLights {
    ctx.setFillColor(color)
    ctx.fillEllipse(in: CGRect(x: cx - dotRadius, y: dotY - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
}

// Mini Segmented Control Pill on Right of Titlebar
let segPillRect = CGRect(x: 668, y: dotY - 18, width: 154, height: 36)
ctx.addPath(roundedRectPath(segPillRect, radius: 10))
ctx.setFillColor(rgba(15, 18, 26, 0.55))
ctx.fillPath()

let activeSegRect = CGRect(x: 718, y: dotY - 14, width: 54, height: 28)
ctx.addPath(roundedRectPath(activeSegRect, radius: 7))
ctx.setFillColor(rgba(10, 132, 255, 0.95))
ctx.fillPath()

// 5. LEFT PANE CONTENT: Markdown Symbol Badge (`M↓`) + Syntax Lines
let mdCardRect = CGRect(x: 154, y: 505, width: 304, height: 220)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: rgba(0, 0, 0, 0.35))
ctx.addPath(roundedRectPath(mdCardRect, radius: 32))
ctx.setFillColor(rgba(30, 37, 52))
ctx.fillPath()
ctx.restoreGState()

ctx.addPath(roundedRectPath(mdCardRect, radius: 32))
ctx.setStrokeColor(rgba(96, 165, 250, 0.35))
ctx.setLineWidth(4)
ctx.strokePath()

// Draw `M` inside the Markdown card
ctx.saveGState()
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.setStrokeColor(rgba(96, 165, 250)) // Vibrant Sky Blue
ctx.setLineWidth(24)

let mPath = CGMutablePath()
mPath.move(to: CGPoint(x: 194, y: 560))
mPath.addLine(to: CGPoint(x: 194, y: 672))
mPath.addLine(to: CGPoint(x: 244, y: 608))
mPath.addLine(to: CGPoint(x: 294, y: 672))
mPath.addLine(to: CGPoint(x: 294, y: 560))
ctx.addPath(mPath)
ctx.strokePath()

// Draw `↓` Down Arrow next to M
ctx.setStrokeColor(rgba(56, 189, 248)) // Cyan highlight
let arrowPath = CGMutablePath()
arrowPath.move(to: CGPoint(x: 378, y: 672))
arrowPath.addLine(to: CGPoint(x: 378, y: 564))
arrowPath.move(to: CGPoint(x: 342, y: 602))
arrowPath.addLine(to: CGPoint(x: 378, y: 560))
arrowPath.addLine(to: CGPoint(x: 414, y: 602))
ctx.addPath(arrowPath)
ctx.strokePath()
ctx.restoreGState()

// Syntax-Highlighted Markdown Code Bars below the M↓ card
struct CodeBar {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let color: CGColor
}

let codeBars: [CodeBar] = [
    // Line 1: `# Heading`
    CodeBar(x: 156, y: 432, width: 38, color: rgba(244, 114, 182)), // Pink `#`
    CodeBar(x: 208, y: 432, width: 196, color: rgba(226, 232, 240)),
    // Line 2: `> [!NOTE]`
    CodeBar(x: 156, y: 376, width: 26, color: rgba(56, 189, 248)),
    CodeBar(x: 196, y: 376, width: 148, color: rgba(96, 165, 250, 0.85)),
    // Line 3: ```mermaid
    CodeBar(x: 156, y: 320, width: 112, color: rgba(192, 132, 252)), // Purple fence
    CodeBar(x: 282, y: 320, width: 138, color: rgba(52, 211, 153)), // Mint `mermaid`
    // Line 4: indented node line
    CodeBar(x: 184, y: 264, width: 210, color: rgba(148, 163, 184, 0.75)),
    // Line 5: closing fence
    CodeBar(x: 156, y: 208, width: 92, color: rgba(192, 132, 252))
]

for bar in codeBars {
    let rect = CGRect(x: bar.x, y: bar.y, width: bar.width, height: 24)
    ctx.addPath(roundedRectPath(rect, radius: 12))
    ctx.setFillColor(bar.color)
    ctx.fillPath()
}

// 6. RIGHT PANE CONTENT: Mermaid Flowchart Diagram + GitHub Rendered Elements

// Top Node (Root Flowchart Node)
let topNode = CGRect(x: 632, y: 635, width: 172, height: 74)
// Bottom Left Node
let bottomLeftNode = CGRect(x: 558, y: 420, width: 138, height: 68)
// Bottom Right Node
let bottomRightNode = CGRect(x: 738, y: 420, width: 138, height: 68)

// Connecting Bezier Edges between Mermaid Nodes
ctx.saveGState()
ctx.setStrokeColor(rgba(56, 189, 248, 0.9))
ctx.setLineWidth(10)
ctx.setLineCap(.round)

let leftEdge = CGMutablePath()
leftEdge.move(to: CGPoint(x: topNode.midX - 24, y: topNode.minY))
leftEdge.addCurve(
    to: CGPoint(x: bottomLeftNode.midX, y: bottomLeftNode.maxY),
    control1: CGPoint(x: topNode.midX - 24, y: 555),
    control2: CGPoint(x: bottomLeftNode.midX, y: 565)
)
ctx.addPath(leftEdge)
ctx.strokePath()

let rightEdge = CGMutablePath()
rightEdge.move(to: CGPoint(x: topNode.midX + 24, y: topNode.minY))
rightEdge.addCurve(
    to: CGPoint(x: bottomRightNode.midX, y: bottomRightNode.maxY),
    control1: CGPoint(x: topNode.midX + 24, y: 555),
    control2: CGPoint(x: bottomRightNode.midX, y: 565)
)
ctx.addPath(rightEdge)
ctx.strokePath()
ctx.restoreGState()

// Helper to draw glowing Mermaid diagram node
func drawMermaidNode(_ rect: CGRect, fillStart: CGColor, fillEnd: CGColor, stroke: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 20, color: rgba(0, 0, 0, 0.35))
    let path = roundedRectPath(rect, radius: 20)
    ctx.addPath(path)
    ctx.clip()
    let grad = CGGradient(colorsSpace: colorSpace, colors: [fillStart, fillEnd] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(
        grad,
        start: CGPoint(x: rect.midX, y: rect.maxY),
        end: CGPoint(x: rect.midX, y: rect.minY),
        options: []
    )
    ctx.restoreGState()

    ctx.addPath(roundedRectPath(rect, radius: 20))
    ctx.setStrokeColor(stroke)
    ctx.setLineWidth(4)
    ctx.strokePath()

    // Inner label bar inside node
    let labelWidth = rect.width * 0.56
    let labelRect = CGRect(
        x: rect.midX - labelWidth / 2,
        y: rect.midY - 7,
        width: labelWidth,
        height: 14
    )
    ctx.addPath(roundedRectPath(labelRect, radius: 7))
    ctx.setFillColor(rgba(255, 255, 255, 0.92))
    ctx.fillPath()
}

drawMermaidNode(
    topNode,
    fillStart: rgba(14, 165, 233),
    fillEnd: rgba(2, 132, 199),
    stroke: rgba(125, 211, 252)
)

drawMermaidNode(
    bottomLeftNode,
    fillStart: rgba(16, 185, 129),
    fillEnd: rgba(5, 150, 105),
    stroke: rgba(110, 231, 183)
)

drawMermaidNode(
    bottomRightNode,
    fillStart: rgba(139, 92, 246),
    fillEnd: rgba(109, 40, 217),
    stroke: rgba(196, 181, 253)
)

// GitHub Flavored Preview Callout Card (`> [!TIP]` + Task List) at bottom right
let gfmCardRect = CGRect(x: 562, y: 196, width: 312, height: 164)
ctx.saveGState()
ctx.addPath(roundedRectPath(gfmCardRect, radius: 24))
ctx.setFillColor(rgba(30, 41, 63, 0.9))
ctx.fillPath()
ctx.setStrokeColor(rgba(255, 255, 255, 0.1))
ctx.setLineWidth(3)
ctx.addPath(roundedRectPath(gfmCardRect, radius: 24))
ctx.strokePath()

// Left green GitHub Alert accent stripe
let stripeRect = CGRect(x: gfmCardRect.minX + 16, y: gfmCardRect.minY + 24, width: 10, height: gfmCardRect.height - 48)
ctx.addPath(roundedRectPath(stripeRect, radius: 5))
ctx.setFillColor(rgba(52, 211, 153))
ctx.fillPath()

// Checkmark circle 1
let check1 = CGRect(x: 600, y: 294, width: 34, height: 34)
ctx.addPath(roundedRectPath(check1, radius: 10))
ctx.setFillColor(rgba(16, 185, 129))
ctx.fillPath()

// Checkmark tick inside circle 1
ctx.setStrokeColor(rgba(255, 255, 255))
ctx.setLineWidth(5)
ctx.setLineCap(.round)
ctx.setLineJoin(.round)
ctx.move(to: CGPoint(x: 609, y: 310))
ctx.addLine(to: CGPoint(x: 616, y: 303))
ctx.addLine(to: CGPoint(x: 626, y: 318))
ctx.strokePath()

// Task text bar 1
ctx.addPath(roundedRectPath(CGRect(x: 648, y: 301, width: 196, height: 20), radius: 10))
ctx.setFillColor(rgba(226, 232, 240, 0.9))
ctx.fillPath()

// Checkmark circle 2
let check2 = CGRect(x: 600, y: 232, width: 34, height: 34)
ctx.addPath(roundedRectPath(check2, radius: 10))
ctx.setFillColor(rgba(59, 130, 246))
ctx.fillPath()

ctx.move(to: CGPoint(x: 609, y: 248))
ctx.addLine(to: CGPoint(x: 616, y: 241))
ctx.addLine(to: CGPoint(x: 626, y: 256))
ctx.strokePath()

// Task text bar 2
ctx.addPath(roundedRectPath(CGRect(x: 648, y: 239, width: 156, height: 20), radius: 10))
ctx.setFillColor(rgba(148, 163, 184, 0.8))
ctx.fillPath()
ctx.restoreGState()

// 7. CENTER SPLIT-VIEW DIVIDER & TACTILE GRAB PILL
ctx.setFillColor(rgba(255, 255, 255, 0.14))
ctx.fill(CGRect(x: splitX - 3, y: iconRect.minY, width: 6, height: iconRect.height - titlebarHeight))

// Glowing Grab Handle Pill in Center of Divider
let handleRect = CGRect(x: splitX - 13, y: 405, width: 26, height: 114)
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: 0), blur: 18, color: rgba(56, 189, 248, 0.75))
ctx.addPath(roundedRectPath(handleRect, radius: 13))
ctx.setFillColor(rgba(56, 189, 248))
ctx.fillPath()
ctx.restoreGState()

// Inner white grip core
let innerGrip = CGRect(x: splitX - 4, y: 432, width: 8, height: 60)
ctx.addPath(roundedRectPath(innerGrip, radius: 4))
ctx.setFillColor(rgba(255, 255, 255, 0.95))
ctx.fillPath()

// 8. Inner Specular Rim Border around Squircle
ctx.restoreGState() // Remove clip
ctx.saveGState()
ctx.addPath(mainSquircle)
ctx.setStrokeColor(rgba(255, 255, 255, 0.22))
ctx.setLineWidth(6)
ctx.strokePath()
ctx.restoreGState()

// Save PNG
guard let cgImage = ctx.makeImage() else {
    fatalError("Failed to make CGImage")
}

let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
    fatalError("Failed to encode PNG")
}

let outURL = URL(fileURLWithPath: outputPath)
try pngData.write(to: outURL)
print("Generated 1024x1024 icon at \(outURL.path)")
