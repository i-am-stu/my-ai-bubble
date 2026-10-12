
let app = NSApplication.shared
app.setActivationPolicy(.accessory)
let test = AppDelegate()
test.defaults.removePersistentDomain(forName:"local.myaibubble.behaviour-tests")
test.defaults.set(false,forKey:"soundsEnabled")
for count in [0, 1, 6, 10] {
    test.apps = Array(repeating: "/System/Applications/Calculator.app", count: count)
    test.expanded = true; test.rebuild()
    assert(test.iconPanels.count == count)
    assert(test.panels.allSatisfy { !$0.isMovable && !$0.isMovableByWindowBackground })
    let centre = test.panels[0].contentView as! BubbleView
    for (dx,dy): (CGFloat,CGFloat) in [(13.5,7.25),(-500,-400),(21,-3)] {
        centre.move?(dx,dy)
        let before = test.panels.map { $0.frame }
        centre.finishMove?()
        assert(test.panels.map { $0.frame } == before, "Release moved a window")
    }
    // Dragging into every edge must preserve the whole circular arrangement.
    for delta in [(CGFloat(10000),CGFloat(0)),(-10000,0),(0,10000),(0,-10000)] {
        let offsets = test.iconPanels.map { NSPoint(x:$0.frame.midX-test.anchor.x,y:$0.frame.midY-test.anchor.y) }
        centre.move?(delta.0,delta.1)
        for (panel,offset) in zip(test.iconPanels,offsets) {
            assert(abs(panel.frame.midX-test.anchor.x-offset.x) < 0.01)
            assert(abs(panel.frame.midY-test.anchor.y-offset.y) < 0.01)
        }
        let frames = test.panels.map { $0.frame }
        centre.finishMove?()
        assert(test.panels.map { $0.frame } == frames)
    }
    test.toggle(); test.reducedMotion = false
    test.advanceAnimation(at: test.animationBegan + 0.1)
    if count > 1 { assert(test.iconProgress.first! > test.iconProgress.last!) }
    test.advanceAnimation(at: test.animationBegan + 2)
    assert(test.iconPanels.allSatisfy { !$0.isVisible && $0.ignoresMouseEvents })
    test.toggle(); test.reducedMotion = false
    test.advanceAnimation(at: test.animationBegan + 0.15)
    let intermediate = test.iconProgress
    test.toggle(); assert(test.animationStarts == intermediate)
    test.advanceAnimation(at: test.animationBegan + 2)
    test.toggle(); test.advanceAnimation(at: test.animationBegan + 2)
    assert(test.iconPanels.allSatisfy { $0.isVisible && !$0.ignoresMouseEvents })
    test.toggle(); test.reducedMotion = true
    test.advanceAnimation(at: test.animationBegan + 0.2)
    assert(test.iconProgress.allSatisfy { $0 == 0 })
    test.panels.forEach { $0.close() }
}
// Small movements must accumulate even while the displayed group is edge-clamped.
if let screen = NSScreen.main {
    test.apps = ["/A.app"]; test.expanded = true
    test.anchor = NSPoint(x:screen.visibleFrame.maxX-117,y:screen.visibleFrame.midY)
    test.rebuild()
    let core = test.panels[0].contentView as! BubbleView
    let start = test.anchor
    for _ in 0..<150 { core.move?(1,0) }
    assert(abs(test.dragAnchor!.x-(start.x+150)) < 0.01)
    core.finishMove?(); assert(test.dragAnchor == nil)
    test.panels.forEach { $0.close() }
}
// Simulate an external/native move of just the centre, including resizing.
test.apps = ["/A.app", "/B.app"]; test.expanded = true; test.clamp(); test.rebuild()
let protectedCore = test.panels[0]
let expectedCore = protectedCore.frame
protectedCore.setFrame(NSRect(x:0,y:0,width:80,height:80),display:true)
RunLoop.main.run(until:Date(timeIntervalSinceNow:0.1))
assert(protectedCore.frame == expectedCore, "External reposition escaped the group")
test.panels.forEach { $0.close() }
// Reordering keeps the dragged app's panel/action identity and persists its order.
test.apps = ["/A.app", "/B.app", "/C.app", "/D.app"]
test.expanded = true; test.rebuild()
let originalPanels = test.iconPanels
let originalAnchor = test.anchor
func dragToSlot(_ path: String, _ slot: Int) {
    let angle = test.appAngle(slot)
    test.reorderApp(path, toward: NSPoint(x:test.anchor.x+82*cos(angle), y:test.anchor.y+82*sin(angle)))
}
dragToSlot("/A.app", 2)
assert(test.apps == ["/B.app", "/C.app", "/A.app", "/D.app"])
assert(test.iconPanels[2] === originalPanels[0])
assert(test.anchor == originalAnchor)
test.finishReordering()
assert(test.defaults.stringArray(forKey:"apps") == test.apps)
assert(test.draggingApp == nil)
dragToSlot("/D.app", 0); test.finishReordering()
assert(test.apps == ["/D.app", "/B.app", "/C.app", "/A.app"])
test.toggle(); test.advanceAnimation(at:test.animationBegan+2)
test.toggle(); test.advanceAnimation(at:test.animationBegan+2)
assert(test.apps == ["/D.app", "/B.app", "/C.app", "/A.app"])
test.rebuild()
assert(test.apps == test.defaults.stringArray(forKey:"apps"))
test.apps = ["/A.app"]; test.rebuild(); dragToSlot("/A.app",0); test.finishReordering()
assert(test.apps == ["/A.app"])
test.panels.forEach { $0.close() }
// Reject invalid persisted launch targets and invalid geometry without crashing.
let calculator = "/System/Applications/Calculator.app"
assert(test.validApplication(calculator))
assert(!test.validApplication("https://example.com/Fake.app"))
assert(!test.validApplication("/bin/sh"))
assert(!test.validApplication("/missing/Fake.app"))
assert(test.validatedApps([calculator, calculator, "/bin/sh"]) == [calculator])
let fixture = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at: fixture, withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:fixture) }
var candidates: [String] = []
for index in 0..<12 {
    let url = fixture.appendingPathComponent("Test\(index).app")
    try FileManager.default.createSymbolicLink(at:url, withDestinationURL:URL(fileURLWithPath:calculator))
    candidates.append(url.path)
}
assert(test.validatedApps(candidates).count == 10)
test.anchor = NSPoint(x:CGFloat.nan, y:CGFloat.infinity); test.clamp()
assert(test.anchor.x.isFinite && test.anchor.y.isFinite)
let invalidRemoval = NSMenuItem(); invalidRemoval.tag = -1
let beforeRemoval = test.apps; test.removeApp(invalidRemoval)
assert(test.apps == beforeRemoval)
test.toggleSounds(); assert(test.soundsEnabled)
test.toggleSounds(); assert(!test.soundsEnabled)
test.apps = ["/A.app", "/B.app"]; test.expanded = true; test.rebuild()
test.updateActiveApp("/A.app")
assert(test.appViews["/A.app"]!.isActiveApp && !test.appViews["/B.app"]!.isActiveApp)
test.updateActiveApp("/B.app")
assert(!test.appViews["/A.app"]!.isActiveApp && test.appViews["/B.app"]!.isActiveApp)
test.updateActiveApp("/Other.app")
assert(test.appViews.values.allSatisfy { !$0.isActiveApp })
test.updateActiveApp(nil)
assert(test.appViews.values.allSatisfy { !$0.isActiveApp })
test.panels.forEach { $0.close() }
assert(BubbleView.coreArtwork != nil, "Artwork resource missing")
assert(BubbleView.glassBase != nil, "Core Image setup failed")
let menuTitles = test.makeMenu().items.map { $0.title }.joined(separator: " ").lowercased()
assert(!menuTitles.contains("alert") && !menuTitles.contains("notification"))
let usageDefaults = UserDefaults(suiteName:"local.myaibubble.usage-tests")!
usageDefaults.removePersistentDomain(forName:"local.myaibubble.usage-tests")
let tracker = UsageTracker(defaults:usageDefaults)
let today = Date()
tracker.record(path:"/A.app",seconds:120,switches:2,at:today)
tracker.record(path:"/B.app",seconds:60,switches:1,at:today)
tracker.record(path:"/A.app",seconds:999,at:Calendar.current.date(byAdding:.day,value:-8,to:today)!)
assert(tracker.weekly()["/A.app"]!.seconds == 120)
assert(tracker.weekly()["/A.app"]!.switches == 2)
tracker.enabled = false; tracker.record(path:"/A.app",seconds:50,switches:1)
assert(tracker.weekly()["/A.app"]!.seconds == 120)
tracker.save()
assert(UsageTracker(defaults:usageDefaults).weekly()["/B.app"]!.seconds == 60)
assert(UsageTracker.activeSeconds(elapsed:2,idle:0) == 2)
assert(UsageTracker.activeSeconds(elapsed:2,idle:70) == 0)
assert(UsageTracker.activeSeconds(elapsed:300,idle:0) == 0)
tracker.clear(); assert(tracker.weekly().isEmpty)
usageDefaults.removePersistentDomain(forName:"local.myaibubble.usage-tests")
test.apps = ["/A.app", "/B.app"]; test.expanded = true
let smallChoice = NSMenuItem(); smallChoice.tag = 1; test.setBubbleSize(smallChoice)
assert(test.panels[0].frame.width == 72 && test.iconPanels[0].frame.width == 53)
assert(test.panels[0].contentView!.bounds.width == 96)
assert(test.orbitRadius == 61.5)
let smallCore = test.panels[0].contentView as! BubbleView
smallCore.move?(8,6); let smallFrames = test.panels.map { $0.frame }; smallCore.finishMove?()
assert(test.panels.map { $0.frame } == smallFrames)
smallChoice.tag = 0; test.setBubbleSize(smallChoice)
assert(test.panels[0].frame.width == 96 && test.orbitRadius == 82)
// Each visible edge stays within one point of the same 10-point gap.
if let screen = NSScreen.main {
    for small in [false, true] {
        test.defaults.set(small,forKey:"smallBubbles")
        for count in [0,1,3,7,10] {
            test.apps = Array(repeating:"/A.app",count:count)
            let frame = screen.visibleFrame
            for corner in [NSPoint(x:frame.minX,y:frame.minY), NSPoint(x:frame.maxX-1,y:frame.maxY-1)] {
                test.anchor = corner; test.clamp()
                let bounds = test.visibleBubbleBounds.offsetBy(dx:test.anchor.x,dy:test.anchor.y)
                let gaps = corner.x == frame.minX ? [bounds.minX-frame.minX,bounds.minY-frame.minY] : [frame.maxX-bounds.maxX,frame.maxY-bounds.maxY]
                assert(gaps.allSatisfy { $0 >= 9.99 && $0 < 11.01 })
            }
        }
    }
}
test.panels.forEach { $0.close() }
// A contrasting logo must not turn the sampled tile background grey.
let tile = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:256,pixelsHigh:256,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0)!
let sampler = BubbleView(label:"Example app",size:70)
for background in [NSColor.white, NSColor.black, NSColor.orange] {
    for y in 0..<256 { for x in 0..<256 {
        let c = ((x > 58 && x < 198 && y > 58 && y < 198) ? NSColor.gray : background).usingColorSpace(.deviceRGB)!
        var pixel = [Int(c.redComponent*255),Int(c.greenComponent*255),Int(c.blueComponent*255),255]
        tile.setPixel(&pixel,atX:x,y:y)
    } }
    let actual = sampler.sampledBackground(tile).usingColorSpace(.deviceRGB)!
    let expected = background.usingColorSpace(.deviceRGB)!
    assert(abs(actual.redComponent-expected.redComponent) < 0.01)
    assert(abs(actual.greenComponent-expected.greenComponent) < 0.01)
    assert(abs(actual.blueComponent-expected.blueComponent) < 0.01)
}
let image = NSImage(size: NSSize(width: 480, height: 320))
image.lockFocus()
NSColor(calibratedRed:0.94,green:0.96,blue:0.99,alpha:1).setFill()
NSRect(x:0,y:0,width:480,height:320).fill()
func drawPreview(_ view: BubbleView, _ center: NSPoint) {
    NSGraphicsContext.saveGraphicsState()
    let tr = NSAffineTransform(); tr.translateX(by:center.x-view.bounds.width/2,yBy:center.y-view.bounds.height/2);tr.concat()
    view.draw(view.bounds); NSGraphicsContext.restoreGraphicsState()
}
let core = BubbleView(label:"My AI Bubble",size:96);core.previewTime=0
assert(abs((core.bounds.width-2*core.artworkInset)/46 - 4.0/3.0) < 0.001)
drawPreview(core,NSPoint(x:240,y:160))
let names = ["ChatGPT", "Claude", "Granola", "Perplexity", "superwhisper", "Muse"]
for (index,name) in names.enumerated() {
    let path = "/Applications/\(name).app"
    guard FileManager.default.fileExists(atPath:path) else { continue }
    let view = BubbleView(label:name,icon:NSWorkspace.shared.icon(forFile:path),size:54)
    let angle = CGFloat.pi/2-CGFloat(index)*2*CGFloat.pi/6
    drawPreview(view,NSPoint(x:240+82*cos(angle),y:160+82*sin(angle)))
}
image.unlockFocus()
try NSBitmapImageRep(data:image.tiffRepresentation!)!.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
test.defaults.removePersistentDomain(forName:"local.myaibubble.behaviour-tests")
print("PASS: 0/1/6/10 apps; exact drag release; staggered folding; rapid reversal; hidden click targets; Reduce Motion; artwork; no alert controls")
