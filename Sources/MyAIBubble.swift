import Cocoa
import CoreImage
import UniformTypeIdentifiers

// Original, quiet synthesized cues: no downloaded audio or audio permissions.
final class BubbleAudio {
    private var active: [NSSound] = []
    func stop() { active.forEach { $0.stop() }; active.removeAll() }
    func play(frequency: Double, endFrequency: Double, duration: Double, volume: Float) {
        active.removeAll { !$0.isPlaying }
        let rate = 22050
        let count = Int(Double(rate)*duration)
        var data = Data()
        func word<T: FixedWidthInteger>(_ value: T) {
            var little = value.littleEndian
            withUnsafeBytes(of: &little) { data.append(contentsOf: $0) }
        }
        data.append(contentsOf: "RIFF".utf8); word(UInt32(36+count*2))
        data.append(contentsOf: "WAVEfmt ".utf8); word(UInt32(16))
        word(UInt16(1)); word(UInt16(1)); word(UInt32(rate)); word(UInt32(rate*2))
        word(UInt16(2)); word(UInt16(16))
        data.append(contentsOf: "data".utf8); word(UInt32(count*2))
        var phase = 0.0
        for index in 0..<count {
            let t = Double(index)/Double(rate), fraction = Double(index)/Double(count)
            phase += 2*Double.pi*(frequency+(endFrequency-frequency)*fraction)/Double(rate)
            let envelope = min(1,t/0.008)*pow(1-fraction,3)
            let sample = (sin(phase)+0.16*sin(phase*2))*envelope*0.45
            word(Int16(sample*32767))
        }
        guard let sound = NSSound(data:data) else { return }
        sound.volume = volume; active.append(sound); sound.play()
    }
    func click() { play(frequency:620,endFrequency:420,duration:0.065,volume:0.22) }
    func bubble(opening: Bool, rank: Int) {
        let pitch = opening ? 780+Double(rank)*45 : 650-Double(rank)*25
        play(frequency:pitch,endFrequency:pitch*(opening ? 1.12 : 0.78),duration:0.095,volume:0.12)
    }
}

final class BubblePanel: NSPanel, NSWindowDelegate {
    private var intendedFrame: NSRect?
    private var placing = false
    private var repairPending = false
    func place(at origin: NSPoint) {
        var target = frame; target.origin = origin
        intendedFrame = target
        placing = true
        super.setFrame(target, display:true)
        placing = false
    }
    override func setFrame(_ frameRect: NSRect, display flag: Bool) {
        super.setFrame(placing ? frameRect : (intendedFrame ?? frameRect), display:flag)
    }
    override func setFrameOrigin(_ point: NSPoint) {
        super.setFrameOrigin(placing ? point : (intendedFrame?.origin ?? point))
    }
    func windowDidMove(_ notification: Notification) { restoreGroupPosition() }
    func windowDidResize(_ notification: Notification) { restoreGroupPosition() }
    private func restoreGroupPosition() {
        guard !placing, !repairPending, let target = intendedFrame, frame != target else { return }
        repairPending = true
        // Defer until the native move completes, and use the newest drag target.
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.repairPending = false
            guard self.isVisible, let target = self.intendedFrame, self.frame != target else { return }
            NSLog("My AI Bubble: correcting displaced panel %@ from %@ to %@", self.contentView?.accessibilityLabel() ?? "bubble", NSStringFromRect(self.frame), NSStringFromRect(target))
            self.placing = true
            self.setFrame(target, display:true)
            self.placing = false
        }
    }
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    // The group handles screen edges; AppKit must not move each bubble separately.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}
final class BubbleView: NSView {
    let label: String
    let icon: NSImage?
    static let coreArtwork: NSImage? = {
        guard let path = Bundle.main.path(forResource: "BubbleArtwork", ofType: "png") else { return nil }
        return NSImage(contentsOfFile: path)
    }()
    // Draw and sample the same resolved icon representation. Native icon bundles
    // can use different artwork/colours at different sizes.
    lazy var resolvedIcon: NSImage? = {
        guard let icon = icon,
              let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 256, pixelsHigh: 256, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return icon }
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current = context
        icon.draw(in: NSRect(x: 0, y: 0, width: 256, height: 256))
        NSGraphicsContext.restoreGraphicsState()
        let samples = [(64,64), (192,64), (64,192), (192,192)].compactMap { bitmap.colorAt(x: $0.0, y: $0.1)?.usingColorSpace(.deviceRGB) }
        if samples.count == 4 {
            let r = samples.reduce(CGFloat(0)) { $0+$1.redComponent }/4
            let g = samples.reduce(CGFloat(0)) { $0+$1.greenComponent }/4
            let b = samples.reduce(CGFloat(0)) { $0+$1.blueComponent }/4
            let fill = NSColor(deviceRed: r, green: g, blue: b, alpha: 1)
            // Remove only low-contrast tile shading; retain the contrasting logo.
            for y in 32..<224 { for x in 32..<224 {
                guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB), pixel.alphaComponent > 0.98 else { continue }
                let distance = pow(pixel.redComponent-r,2)+pow(pixel.greenComponent-g,2)+pow(pixel.blueComponent-b,2)
                let colouredBackground = max(r,g,b)-min(r,g,b) > 0.12
                let paleBackground = min(r,g,b) > 0.80
                let palePixel = min(pixel.redComponent, pixel.greenComponent, pixel.blueComponent) > 0.80
                if (colouredBackground && distance < 0.012) || (paleBackground && palePixel && distance < 0.045) {
                    bitmap.setColor(fill, atX: x, y: y)
                }
            } }
        }
        let image = NSImage(size: NSSize(width: 256, height: 256)); image.addRepresentation(bitmap)
        return image
    }()
    lazy var iconBackground: NSColor = {
        guard let bitmap = resolvedIcon?.representations.first as? NSBitmapImageRep else { return .white }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        let points = [(64,64), (192,64), (64,192), (192,192)]
        for (x,y) in points {
            let colour = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) ?? .white
            red += colour.redComponent; green += colour.greenComponent; blue += colour.blueComponent
        }
        return NSColor(deviceRed: red/4, green: green/4, blue: blue/4, alpha: 1)
    }()
    var reveal: CGFloat = 1 { didSet { needsDisplay = true } }
    var isActiveApp = false { didSet { if oldValue != isActiveApp { needsDisplay = true } } }
    var hovered = false
    var hoverArea: NSTrackingArea?
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let area = hoverArea { removeTrackingArea(area) }
        let area = NSTrackingArea(rect: bounds, options: [.mouseEnteredAndExited, .activeAlways], owner: self)
        addTrackingArea(area); hoverArea = area
    }
    override func mouseEntered(with event: NSEvent) { hovered = true; needsDisplay = true }
    override func mouseExited(with event: NSEvent) { hovered = false; needsDisplay = true }
    var action: (() -> Void)?
    var move: ((CGFloat, CGFloat) -> Void)?
    var finishMove: (() -> Void)?
    var context: (() -> NSMenu)?
    var dragTo: ((NSPoint) -> Void)?
    var pressPoint = NSPoint.zero
    var pressCentre = NSPoint.zero
    var lastPoint = NSPoint.zero
    var dragged = false
    init(label: String, icon: NSImage? = nil, size: CGFloat) {
        self.label = label; self.icon = icon
        super.init(frame: NSRect(x: 0, y: 0, width: size + (icon == nil ? 0 : 16), height: size + (icon == nil ? 0 : 16)))
        toolTip = icon == nil ? "Drag to move • Click to fold • Right-click for options" : label
        setAccessibilityElement(true)
        setAccessibilityLabel(label)
        setAccessibilityRole(.button)
    }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) {
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        let scale: CGFloat = icon == nil ? (hovered ? 1.025 : 1) : (0.35 + 0.65 * reveal) * (hovered ? 1.06 : 1)
        // Draw in unscaled window coordinates so hover cannot displace the shadow.
        let diameter = (bounds.width-24)*scale
        let shadowBounds = NSRect(x:bounds.midX-diameter/2, y:bounds.midY-diameter/2, width:diameter, height:diameter)
        drawSoftShadow(under:NSBezierPath(ovalIn:shadowBounds), blur:icon == nil ? 11 : 5,
                       offset:icon == nil ? -2 : -1.5, opacity:icon == nil ? 0.075 : 0.10)
        if icon != nil && isActiveApp { drawActiveGlow(around:shadowBounds) }
        let transform = NSAffineTransform()
        transform.translateX(by: bounds.midX, yBy: bounds.midY)
        transform.scale(by: scale)
        transform.translateX(by: -bounds.midX, yBy: -bounds.midY); transform.concat()
        if let icon = resolvedIcon {
            let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 12, dy: 12))
            NSGraphicsContext.saveGraphicsState()
            circle.addClip()
            iconBackground.setFill(); circle.fill()
            let logoBounds = bounds.insetBy(dx: 17, dy: 17)
            NSBezierPath(ovalIn: logoBounds).addClip()
            // Crop the native icon's outer padding and rounded tile edges.
            let source = NSRect(x: icon.size.width * 0.13, y: icon.size.height * 0.13, width: icon.size.width * 0.74, height: icon.size.height * 0.74)
            icon.draw(in: logoBounds, from: source, operation: .sourceOver, fraction: 1)
            NSGraphicsContext.restoreGraphicsState()
        } else {
            drawCore()
        }
    }
    func drawActiveGlow(around circle: NSRect) {
        guard let gradient = NSGradient(colors:[
            NSColor(calibratedRed:0.22,green:0.85,blue:1,alpha:1),
            NSColor(calibratedRed:0.43,green:0.35,blue:1,alpha:1),
            NSColor(calibratedRed:1,green:0.35,blue:0.78,alpha:1),
            NSColor(calibratedRed:1,green:0.77,blue:0.35,alpha:1)]) else { return }
        // Feathered outer halo and a narrow coloured rim. No animation timer.
        for (width, opacity): (CGFloat, CGFloat) in [(9,0.045),(7.5,0.065),(6,0.10),(4.5,0.16),(3,0.24),(1.6,0.90)] {
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current?.cgContext.setAlpha(opacity)
            let ring = NSBezierPath(ovalIn:circle.insetBy(dx:-width,dy:-width))
            ring.append(NSBezierPath(ovalIn:circle.insetBy(dx:0.3,dy:0.3)))
            ring.windingRule = .evenOdd; ring.addClip()
            gradient.draw(in:circle.insetBy(dx:-9,dy:-9),angle:35)
            NSGraphicsContext.restoreGraphicsState()
        }
    }
    func drawSoftShadow(under shape: NSBezierPath, blur: CGFloat, offset: CGFloat, opacity: CGFloat = 0.10) {
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        NSGraphicsContext.saveGraphicsState()
        // Paint only a diffuse shadow. No opaque duplicate under the antialiased edge.
        let shift: CGFloat = 10000
        let displaced = shape.copy() as! NSBezierPath
        let transform = NSAffineTransform(); transform.translateX(by: shift, yBy: 0)
        displaced.transform(using: transform as AffineTransform)
        context.setShadow(offset: CGSize(width: -shift, height: offset), blur: blur,
                          color: NSColor.black.withAlphaComponent(opacity).cgColor)
        NSColor.black.setFill(); displaced.fill()
        NSGraphicsContext.restoreGraphicsState()
    }
    private var lightTimer: Timer?
    private let lightEpoch = ProcessInfo.processInfo.systemUptime
    private var lastGlassFrame: CGImage?
    var previewTime: Double?
    static let glassContext = CIContext(options: [.cacheIntermediates: false])
    static let glassBase: CIImage? = {
        guard let artwork = coreArtwork else { return nil }
        let image = NSImage(size: NSSize(width: 144, height: 144))
        image.lockFocus()
        let source = NSRect(x: artwork.size.width * 372/1200, y: artwork.size.height * 91/630,
                            width: artwork.size.width * 456/1200, height: artwork.size.height * 448/630)
        artwork.draw(in: NSRect(x: 0, y: 0, width: 144, height: 144), from: source, operation: .sourceOver, fraction: 1)
        image.unlockFocus()
        guard let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let input = CIImage(cgImage: cg)
        return input.transformed(by: CGAffineTransform(scaleX: 144/input.extent.width, y: 144/input.extent.height))
    }()
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        lightTimer?.invalidate(); lightTimer = nil
        guard icon == nil, window != nil else { return }
        let timer = Timer(timeInterval: 1.0/24, repeats: true) { [weak self] _ in
            guard let self = self, self.window?.isVisible == true else { return }
            if !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.needsDisplay = true }
        }
        lightTimer = timer; RunLoop.main.add(timer, forMode: .common)
    }
    deinit { lightTimer?.invalidate() }
    func drawCore() {
        guard let base = Self.glassBase else { return }
        let reduced = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let t = previewTime ?? (reduced ? 0 : ProcessInfo.processInfo.systemUptime-lightEpoch)
        // Distort only the inner glass. The outer silhouette, size and position stay fixed.
        var glass = base
        if !reduced || previewTime != nil {
            glass = glass.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: 72+16*sin(t*0.29), y: 72+14*cos(t*0.23)),
                kCIInputRadiusKey: 46, kCIInputScaleKey: 0.10*sin(t*0.41)])
            glass = glass.applyingFilter("CITwirlDistortion", parameters: [
                kCIInputCenterKey: CIVector(x: 72, y: 72), kCIInputRadiusKey: 62,
                kCIInputAngleKey: 0.13*sin(t*0.31)])
            glass = glass.applyingFilter("CIHueAdjust", parameters: [kCIInputAngleKey: 0.09*sin(t*0.19)])
        }
        let destination = bounds.insetBy(dx: 12, dy: 12)
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSBezierPath(ovalIn: destination).addClip()
        let opaqueGlass = glass.composited(over: CIImage(color: CIColor(red: 0.2, green: 0.4, blue: 0.8, alpha: 1)))
        // If a transient rendering failure occurs, retain the previous valid glass frame.
        if let frame = Self.glassContext.createCGImage(opaqueGlass, from: CGRect(x:0,y:0,width:144,height:144)) {
            lastGlassFrame = frame
        }
        if let frame = lastGlassFrame {
            NSImage(cgImage: frame, size: NSSize(width:144,height:144)).draw(in: destination, from: .zero, operation: .sourceOver, fraction: 1)
        }
        // Broad, faint reflections drift across the artwork rather than pulsing its scale.
        if let context = NSGraphicsContext.current?.cgContext {
            context.setBlendMode(.screen)
            for (phase, tint) in [(0.0, NSColor.white), (2.4, NSColor(calibratedRed:0.50,green:0.88,blue:1,alpha:1))] {
                let x = bounds.midX + 17*sin(t*0.24+phase)
                let y = bounds.midY + 19*cos(t*0.18+phase)
                let colours = [tint.withAlphaComponent(0.13).cgColor, tint.withAlphaComponent(0).cgColor] as CFArray
                if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colours, locations: [0,1]) {
                    context.drawRadialGradient(gradient, startCenter: CGPoint(x:x,y:y), startRadius:0, endCenter:CGPoint(x:x,y:y), endRadius:22, options: [])
                }
            }
        }
    }
    override func mouseDown(with event: NSEvent) {
        lastPoint = NSEvent.mouseLocation; pressPoint = lastPoint; dragged = false
        if let frame = window?.frame { pressCentre = NSPoint(x: frame.midX, y: frame.midY) }
    }
    override func mouseDragged(with event: NSEvent) {
        let point = NSEvent.mouseLocation
        if let dragTo = dragTo {
            let dx = point.x-pressPoint.x, dy = point.y-pressPoint.y
            guard dragged || hypot(dx,dy) >= 5 else { return }
            dragged = true
            dragTo(NSPoint(x: pressCentre.x+dx, y: pressCentre.y+dy))
            return
        }
        guard move != nil else { return }
        let dx = point.x-lastPoint.x, dy = point.y-lastPoint.y
        if hypot(point.x-pressPoint.x, point.y-pressPoint.y) > 1 { dragged = true }
        move?(dx,dy); lastPoint = point
    }
    override func mouseUp(with event: NSEvent) { if dragged { finishMove?() } else { action?() } }
    override func menu(for event: NSEvent) -> NSMenu? { context?() }
    override func accessibilityPerformPress() -> Bool { action?(); return true }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    var panels: [BubblePanel] = []
    var apps: [String] = []
    var anchor = NSPoint(x: 160, y: 350)
    var dragAnchor: NSPoint?
    var expanded = true
    var iconPanels: [BubblePanel] = []
    var orbitRadius: CGFloat { 82 }
    func appAngle(_ index: Int) -> CGFloat { .pi/2 - CGFloat(index)*2 * .pi/CGFloat(max(1, apps.count)) }
    var draggingApp: String?
    var draggingAngle: CGFloat?
    var iconProgress: [CGFloat] = []
    var animation: Timer?
    var animationStarts: [CGFloat] = []
    var animationBegan: TimeInterval = 0
    let audio = BubbleAudio()
    var soundedBubbles = Set<Int>()
    var soundsEnabled: Bool { defaults.object(forKey:"soundsEnabled") == nil || defaults.bool(forKey:"soundsEnabled") }
    var reducedMotion = false
    var status: NSStatusItem!
    var appViews: [String: BubbleView] = [:]
    let defaults = UserDefaults.standard
    func applicationDidFinishLaunching(_ notification: Notification) {
        defaults.removeObject(forKey: "dockAlerts")
        let names = ["ChatGPT", "Claude", "Granola", "Perplexity", "ChatGPT Atlas", "superwhisper"]
        let roots = [URL(fileURLWithPath: "/Applications"), FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]
        let initial = names.compactMap { name in
            roots.map { $0.appendingPathComponent(name + ".app").path }.first { FileManager.default.fileExists(atPath: $0) }
        }
        apps = validatedApps(defaults.stringArray(forKey: "apps") ?? initial)
        if defaults.object(forKey: "x") != nil { anchor = NSPoint(x: defaults.double(forKey: "x"), y: defaults.double(forKey: "y")) }
        clamp(); rebuild()
        NSWorkspace.shared.notificationCenter.addObserver(self, selector:#selector(frontmostAppChanged), name:NSWorkspace.didActivateApplicationNotification, object:nil)
        status = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        status.button?.title = "◎"
        status.button?.toolTip = "My AI Bubble"
        status.menu = makeMenu()
        NotificationCenter.default.addObserver(self, selector: #selector(screenChanged), name: NSApplication.didChangeScreenParametersNotification, object: nil)
    }
    // Preferences are local data, not instructions to open arbitrary files or URLs.
    func validApplication(_ path: String) -> Bool {
        guard path.hasPrefix("/"), URL(fileURLWithPath: path).pathExtension.lowercased() == "app",
              let bundle = Bundle(path: path),
              bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String == "APPL",
              let executable = bundle.executableURL else { return false }
        return FileManager.default.isExecutableFile(atPath: executable.path)
    }
    func validatedApps(_ paths: [String]) -> [String] {
        var seen = Set<String>()
        return Array(paths.filter { validApplication($0) && seen.insert($0).inserted }.prefix(10))
    }
    func clamp() {
        if !anchor.x.isFinite || !anchor.y.isFinite { anchor = NSPoint(x: 160, y: 350) }
        let screen = NSScreen.screens.first { $0.visibleFrame.contains(anchor) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let margin: CGFloat = expanded && !apps.isEmpty ? 117 : 52
        anchor.x = max(frame.minX+margin, min(anchor.x, frame.maxX-margin))
        anchor.y = max(frame.minY+margin, min(anchor.y, frame.maxY-margin))
    }
    func save() { defaults.set(anchor.x, forKey: "x"); defaults.set(anchor.y, forKey: "y"); defaults.set(apps, forKey: "apps") }
    func panel(view: BubbleView, centre: NSPoint) -> BubblePanel {
        let size = view.frame.width
        let panel = BubblePanel(contentRect: NSRect(x: centre.x-size/2, y: centre.y-size/2, width: size, height: size), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        // Movement belongs exclusively to our mouse handlers. Native window dragging
        // can trigger macOS edge tiling and relocate the centre independently.
        panel.isMovable = false
        panel.isMovableByWindowBackground = false
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false
        panel.delegate = panel
        panel.place(at:panel.frame.origin)
        panel.isExcludedFromWindowsMenu = true
        panel.level = .floating; panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenDisallowsTiling, .auxiliary]
        panel.minSize = panel.frame.size
        panel.maxSize = panel.frame.size
        panel.isReleasedWhenClosed = false; panel.contentView = view
        panel.orderFrontRegardless(); return panel
    }
    func rebuild() {
        animation?.invalidate(); animation = nil
        audio.stop()
        draggingApp = nil; draggingAngle = nil
        dragAnchor = nil
        panels.forEach { $0.close() }; panels.removeAll(); appViews.removeAll(); iconPanels.removeAll()
        iconProgress = Array(repeating: expanded ? 1 : 0, count: apps.count)
        let centre = BubbleView(label: "My AI Bubble", size: 96)
        centre.action = { [weak self] in self?.toggle() }
        centre.move = { [weak self] dx,dy in
            guard let self = self else { return }
            // Keep the unconstrained drag target: clamping the previous position
            // loses small movements at a monitor seam and prevents slow crossing.
            var target = self.dragAnchor ?? self.anchor
            target.x += dx; target.y += dy
            self.dragAnchor = target
            self.anchor = target
            self.clamp()
            // Position every panel from the shared anchor, then refresh the transparent core.
            self.layoutIcons()
            self.refreshCentre()

        }
        centre.finishMove = { [weak self] in
            guard let self = self, let core = self.panels.first else { return }
            // Persist the actual dropped position without clamping or relaying out windows.
            self.anchor = NSPoint(x: core.frame.midX, y: core.frame.midY)
            self.dragAnchor = nil
            self.refreshCentre()
            self.save()
        }
        centre.context = { [weak self] in self?.makeMenu() ?? NSMenu() }
        panels.append(panel(view: centre, centre: anchor))
        do {
            for (index,path) in apps.enumerated() {
                let angle = appAngle(index)
                let point = NSPoint(x: anchor.x+orbitRadius*cos(angle), y: anchor.y+orbitRadius*sin(angle))
                let name = URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent
                let view = BubbleView(label: name, icon: NSWorkspace.shared.icon(forFile: path), size: 54)
                view.action = { [weak self] in self?.launch(path) }
                view.toolTip = "\(name) • Click to open • Drag around the centre to reorder"
                view.dragTo = { [weak self] point in self?.reorderApp(path, toward: point) }
                view.finishMove = { [weak self] in self?.finishReordering() }
                appViews[path] = view
                let satellite = panel(view: view, centre: point)
                panels.append(satellite); iconPanels.append(satellite)
            }
        }
        layoutIcons()
        updateActiveApp(NSWorkspace.shared.frontmostApplication?.bundleURL?.path)
        panels.first?.orderFrontRegardless()
        status?.menu = makeMenu()
    }
    @objc func frontmostAppChanged(_ notification: Notification) {
        let application = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        updateActiveApp(application?.bundleURL?.path)
    }
    func updateActiveApp(_ path: String?) {
        let active = path.map { URL(fileURLWithPath:$0).resolvingSymlinksInPath().standardizedFileURL.path }
        for (appPath,view) in appViews {
            view.isActiveApp = active == URL(fileURLWithPath:appPath).resolvingSymlinksInPath().standardizedFileURL.path
        }
    }
    func refreshCentre() {
        guard let core = panels.first else { return }
        core.alphaValue = 1
        core.orderFrontRegardless()
        core.contentView?.needsDisplay = true
        core.displayIfNeeded()
    }
    func layoutIcons() {
        panels.first?.place(at:NSPoint(x: anchor.x-48, y: anchor.y-48))
        for (index, panel) in iconPanels.enumerated() {
            let progress = iconProgress[index]
            let angle = apps[index] == draggingApp ? (draggingAngle ?? appAngle(index)) : appAngle(index)
            let distance: CGFloat = reducedMotion ? orbitRadius : orbitRadius * progress
            panel.place(at:NSPoint(x: anchor.x+distance*cos(angle)-panel.frame.width/2, y: anchor.y+distance*sin(angle)-panel.frame.height/2))
            panel.alphaValue = progress
            panel.ignoresMouseEvents = progress < 0.98
            (panel.contentView as? BubbleView)?.reveal = reducedMotion ? 1 : progress
            if progress < 0.001 { panel.orderOut(nil) }
            else if !panel.isVisible {
                panel.orderFrontRegardless()
                if let core = panels.first { panel.order(.below, relativeTo: core.windowNumber) }
            }
        }
    }
    func reorderApp(_ path: String, toward point: NSPoint) {
        guard expanded, let source = apps.firstIndex(of: path) else { return }
        let dx = point.x-anchor.x, dy = point.y-anchor.y
        // Avoid unstable angles if the pointer crosses the centre.
        guard hypot(dx,dy) > 20 else { return }
        animation?.invalidate(); animation = nil
        iconProgress = Array(repeating: 1, count: apps.count)
        draggingApp = path; draggingAngle = atan2(dy,dx)
        let turn = 2 * CGFloat.pi
        let clockwise = (CGFloat.pi/2-draggingAngle!+turn).truncatingRemainder(dividingBy: turn)
        let target = Int((clockwise/turn*CGFloat(apps.count)).rounded()) % apps.count
        if source != target {
            let app = apps.remove(at: source); apps.insert(app, at: target)
            let panel = iconPanels.remove(at: source); iconPanels.insert(panel, at: target)
        }
        layoutIcons()
        iconPanels[target].orderFrontRegardless()
    }
    func finishReordering() {
        guard draggingApp != nil else { return }
        draggingApp = nil; draggingAngle = nil
        layoutIcons(); save()
        status?.menu = makeMenu()
    }
    func advanceAnimation(at now: TimeInterval) {
        let elapsed = now-animationBegan
        var complete = true
        for index in iconProgress.indices {
            let rank = expanded ? index : iconProgress.count-1-index
            let delay = reducedMotion ? 0 : Double(rank) * 0.055
            if elapsed >= delay && !soundedBubbles.contains(index) {
                soundedBubbles.insert(index)
                // Reduced Motion folds together; use just one quiet cue.
                if soundsEnabled && (!reducedMotion || rank == 0) && abs(animationStarts[index]-(expanded ? 1 : 0)) > 0.01 {
                    audio.bubble(opening:expanded,rank:rank)
                }
            }
            let duration = reducedMotion ? 0.12 : 0.32
            let t = max(0, min(1, (elapsed-delay)/duration))
            let eased = CGFloat(t*t*(3-2*t))
            let target: CGFloat = expanded ? 1 : 0
            iconProgress[index] = animationStarts[index] + (target-animationStarts[index])*eased
            if t < 1 { complete = false }
        }
        layoutIcons()
        if complete { animation?.invalidate(); animation = nil }
    }
    func launch(_ path: String) {
        guard apps.contains(path), validApplication(path) else {
            let alert = NSAlert(); alert.messageText = "This app is no longer available"
            alert.informativeText = "Remove its bubble and add the installed app again from the centre bubble’s menu."
            NSApp.activate(ignoringOtherApps: true); alert.runModal(); return
        }
        let config = NSWorkspace.OpenConfiguration(); config.activates = true
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path), configuration: config) { _,error in
            if let error = error { DispatchQueue.main.async { let alert = NSAlert(); alert.messageText = "Couldn’t open this app"; alert.informativeText = error.localizedDescription; alert.runModal() } }
        }
    }
    func item(_ title: String, _ action: Selector, in menu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: ""); item.target = self; menu.addItem(item); return item
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        _ = item(expanded ? "Hide app bubbles" : "Show app bubbles", #selector(toggle), in: menu)
        _ = item("Bring bubble into view", #selector(resetPosition), in: menu)
        menu.addItem(.separator())
        let add = item("Add an AI app…", #selector(addApp), in: menu); add.isEnabled = apps.count < 10
        let remove = NSMenuItem(title: "Remove an AI app", action: nil, keyEquivalent: "")
        let submenu = NSMenu()
        for (index,path) in apps.enumerated() { let entry = item(URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent, #selector(removeApp(_:)), in: submenu); entry.tag = index }
        remove.submenu = submenu; menu.addItem(remove)
        menu.addItem(.separator())
        let soundItem = item("Sound effects", #selector(toggleSounds), in:menu)
        soundItem.state = soundsEnabled ? .on : .off
        menu.addItem(.separator()); _ = item("Quit My AI Bubble", #selector(quit), in: menu)
        return menu
    }
    @objc func toggleSounds() {
        defaults.set(!soundsEnabled,forKey:"soundsEnabled")
        if !soundsEnabled { audio.stop() }
        status?.menu = makeMenu()
    }
    @objc func toggle() {
        animation?.invalidate()
        audio.stop(); soundedBubbles.removeAll()
        if soundsEnabled { audio.click() }
        expanded.toggle()
        reducedMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        clamp(); save()
        animationStarts = iconProgress
        animationBegan = ProcessInfo.processInfo.systemUptime
        // Reversals begin from the current positions, including during a stagger.
        let timer = Timer(timeInterval: 1.0/60, repeats: true) { [weak self] _ in
            self?.advanceAnimation(at: ProcessInfo.processInfo.systemUptime)
        }
        animation = timer; RunLoop.main.add(timer, forMode: .common)
        status?.menu = makeMenu()
    }
    @objc func screenChanged() { clamp(); rebuild(); save() }
    @objc func resetPosition() { if let frame = NSScreen.main?.visibleFrame { anchor = NSPoint(x: frame.minX+155, y: frame.midY) }; clamp(); rebuild(); save() }
    @objc func addApp() {
        guard apps.count < 10 else {
            let alert = NSAlert();alert.messageText="You have ten app bubbles"
            alert.informativeText="Remove an AI app from the centre bubble’s right-click menu to make room for another."
            NSApp.activate(ignoringOtherApps:true);alert.runModal();return
        }
        let picker = NSOpenPanel(); picker.title = "Choose an AI app for My AI Bubble"; picker.directoryURL = URL(fileURLWithPath: "/Applications")
        picker.allowedContentTypes = [.applicationBundle]; picker.allowsMultipleSelection = false; picker.canChooseDirectories = false
        NSApp.activate(ignoringOtherApps: true)
        if picker.runModal() == .OK, let url = picker.url, validApplication(url.path), !apps.contains(url.path), apps.count < 10 { apps.append(url.path); expanded = true; clamp(); save(); rebuild() }
    }
    @objc func removeApp(_ sender: NSMenuItem) {
        guard apps.indices.contains(sender.tag) else { return }
        apps.remove(at: sender.tag); save(); rebuild()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
let app = NSApplication.shared
let delegate = AppDelegate()
app.setActivationPolicy(.accessory)
app.delegate = delegate
app.run()
