import Cocoa
import ApplicationServices
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  override func applicationDidFinishLaunching(_ notification: Notification) {
    if let controller = mainFlutterWindow?.contentViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.airpad.desktop/inject",
        binaryMessenger: controller.engine.binaryMessenger
      )

      channel.setMethodCallHandler { (call: FlutterMethodCall, result: @escaping FlutterResult) in
        switch call.method {
        case "checkPermissions":
          let isTrusted = MacInputInjector.shared.checkPermissions()
          result(isTrusted)

        case "injectEvent":
          if let eventData = call.arguments as? [String: Any] {
            MacInputInjector.shared.handleEvent(eventData)
            result(true)
          } else {
            result(FlutterError(code: "INVALID_ARGS", message: "Expected event map", details: nil))
          }

        case "releaseAll":
          MacInputInjector.shared.releaseAll()
          result(true)

        default:
          result(FlutterMethodNotImplemented)
        }
      }
    }

    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return true
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }
}

public class MacInputInjector: NSObject {
  public static let shared = MacInputInjector()

  private var isLeftDown = false
  private var isRightDown = false
  private var isMiddleDown = false
  private var pressedKeyCodes = Set<CGKeyCode>()

  public func checkPermissions() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
  }

  public func handleEvent(_ eventData: [String: Any]) {
    guard let type = eventData["type"] as? String else { return }

    switch type {
    case "move":
      guard let dx = eventData["dx"] as? Double,
            let dy = eventData["dy"] as? Double else { return }
      movePointer(dx: dx, dy: dy)

    case "scroll":
      guard let dx = eventData["dx"] as? Double,
            let dy = eventData["dy"] as? Double else { return }
      scroll(dx: dx, dy: dy)

    case "button":
      guard let button = eventData["button"] as? String,
            let state = eventData["state"] as? String else { return }
      setButtonState(button: button, isDown: state.lowercased() == "down")

    case "click":
      guard let button = eventData["button"] as? String else { return }
      let count = eventData["count"] as? Int ?? 1
      clickButton(button: button, count: count)

    case "key":
      guard let code = eventData["code"] as? String,
            let state = eventData["state"] as? String else { return }
      let mods = eventData["mods"] as? [String] ?? []
      handleKey(code: code, state: state, mods: mods)

    case "text":
      guard let text = eventData["value"] as? String else { return }
      insertText(text)

    case "media":
      guard let action = eventData["action"] as? String else { return }
      handleMediaAction(action)

    case "settings":
      break

    default:
      break
    }
  }

  private func movePointer(dx: Double, dy: Double) {
    let curPos = CGEvent(source: nil)?.location ?? CGPoint.zero
    let newX = max(0, curPos.x + CGFloat(dx))
    let newY = max(0, curPos.y + CGFloat(dy))
    let newPos = CGPoint(x: newX, y: newY)

    let mouseType: CGEventType
    let button: CGMouseButton

    if isLeftDown {
      mouseType = .leftMouseDragged
      button = .left
    } else if isRightDown {
      mouseType = .rightMouseDragged
      button = .right
    } else if isMiddleDown {
      mouseType = .otherMouseDragged
      button = .center
    } else {
      mouseType = .mouseMoved
      button = .left
    }

    if let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: newPos, mouseButton: button) {
      event.post(tap: .cghidEventTap)
    }
  }

  private func scroll(dx: Double, dy: Double) {
    let pixelDy = Int32(dy)
    let pixelDx = Int32(dx)
    if let event = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 2, wheel1: pixelDy, wheel2: pixelDx, wheel3: 0) {
      event.post(tap: .cghidEventTap)
    }
  }

  private func setButtonState(button: String, isDown: Bool) {
    let curPos = CGEvent(source: nil)?.location ?? CGPoint.zero
    let mouseType: CGEventType
    let mouseButton: CGMouseButton

    switch button.lowercased() {
    case "left":
      isLeftDown = isDown
      mouseType = isDown ? .leftMouseDown : .leftMouseUp
      mouseButton = .left
    case "right":
      isRightDown = isDown
      mouseType = isDown ? .rightMouseDown : .rightMouseUp
      mouseButton = .right
    case "middle":
      isMiddleDown = isDown
      mouseType = isDown ? .otherMouseDown : .otherMouseUp
      mouseButton = .center
    default:
      return
    }

    if let event = CGEvent(mouseEventSource: nil, mouseType: mouseType, mouseCursorPosition: curPos, mouseButton: mouseButton) {
      event.post(tap: .cghidEventTap)
    }
  }

  private func clickButton(button: String, count: Int) {
    let curPos = CGEvent(source: nil)?.location ?? CGPoint.zero
    let downType: CGEventType
    let upType: CGEventType
    let mouseButton: CGMouseButton

    switch button.lowercased() {
    case "left":
      downType = .leftMouseDown
      upType = .leftMouseUp
      mouseButton = .left
    case "right":
      downType = .rightMouseDown
      upType = .rightMouseUp
      mouseButton = .right
    case "middle":
      downType = .otherMouseDown
      upType = .otherMouseUp
      mouseButton = .center
    default:
      return
    }

    for i in 1...max(1, count) {
      if let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: curPos, mouseButton: mouseButton) {
        down.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        down.post(tap: .cghidEventTap)
      }
      if let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: curPos, mouseButton: mouseButton) {
        up.setIntegerValueField(.mouseEventClickState, value: Int64(i))
        up.post(tap: .cghidEventTap)
      }
    }
  }

  private func handleKey(code: String, state: String, mods: [String]) {
    guard let vk = mapKeyCode(code) else { return }

    var flags = CGEventFlags()
    for mod in mods {
      switch mod.lowercased() {
      case "ctrl", "control": flags.insert(.maskControl)
      case "alt", "option": flags.insert(.maskAlternate)
      case "shift": flags.insert(.maskShift)
      case "meta", "super", "cmd", "command": flags.insert(.maskCommand)
      default: break
      }
    }

    switch state.lowercased() {
    case "down":
      pressedKeyCodes.insert(vk)
      if let event = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: true) {
        if !flags.isEmpty { event.flags = flags }
        event.post(tap: .cghidEventTap)
      }
    case "up":
      pressedKeyCodes.remove(vk)
      if let event = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: false) {
        if !flags.isEmpty { event.flags = flags }
        event.post(tap: .cghidEventTap)
      }
    case "press", "click":
      if let down = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: true) {
        if !flags.isEmpty { down.flags = flags }
        down.post(tap: .cghidEventTap)
      }
      if let up = CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: false) {
        if !flags.isEmpty { up.flags = flags }
        up.post(tap: .cghidEventTap)
      }
    default:
      break
    }
  }

  private func insertText(_ text: String) {
    for codePoint in text.utf16 {
      var char = codePoint
      if let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true) {
        down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        down.post(tap: .cghidEventTap)
      }
      if let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) {
        up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &char)
        up.post(tap: .cghidEventTap)
      }
    }
  }

  private func handleMediaAction(_ action: String) {
    let keyType: Int32
    switch action.lowercased() {
    case "play_pause": keyType = 16 // NX_KEYTYPE_PLAY
    case "next_track": keyType = 17 // NX_KEYTYPE_NEXT
    case "prev_track": keyType = 18 // NX_KEYTYPE_PREVIOUS
    case "volume_up": keyType = 0   // NX_KEYTYPE_SOUND_UP
    case "volume_down": keyType = 1 // NX_KEYTYPE_SOUND_DOWN
    case "volume_mute": keyType = 7 // NX_KEYTYPE_MUTE
    default: return
    }

    func postAuxKey(key: Int32, isDown: Bool) {
      let state = isDown ? 0xA00 : 0xB00
      let flags = isDown ? 0x100 : 0x0
      let data1 = (key << 16) | Int32(state)

      let ev = NSEvent.otherEvent(
        with: .systemDefined,
        location: .zero,
        modifierFlags: NSEvent.ModifierFlags(rawValue: UInt(flags)),
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        subtype: 8,
        data1: Int(data1),
        data2: -1
      )
      ev?.cgEvent?.post(tap: .cghidEventTap)
    }

    postAuxKey(key: keyType, isDown: true)
    postAuxKey(key: keyType, isDown: false)
  }

  public func releaseAll() {
    let curPos = CGEvent(source: nil)?.location ?? CGPoint.zero

    if isLeftDown {
      CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: curPos, mouseButton: .left)?.post(tap: .cghidEventTap)
      isLeftDown = false
    }
    if isRightDown {
      CGEvent(mouseEventSource: nil, mouseType: .rightMouseUp, mouseCursorPosition: curPos, mouseButton: .right)?.post(tap: .cghidEventTap)
      isRightDown = false
    }
    if isMiddleDown {
      CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: curPos, mouseButton: .center)?.post(tap: .cghidEventTap)
      isMiddleDown = false
    }

    for vk in pressedKeyCodes {
      CGEvent(keyboardEventSource: nil, virtualKey: vk, keyDown: false)?.post(tap: .cghidEventTap)
    }
    pressedKeyCodes.removeAll()
  }

  private func mapKeyCode(_ code: String) -> CGKeyCode? {
    switch code.lowercased() {
    // Letters
    case "a": return 0x00
    case "b": return 0x0B
    case "c": return 0x08
    case "d": return 0x02
    case "e": return 0x0E
    case "f": return 0x03
    case "g": return 0x05
    case "h": return 0x04
    case "i": return 0x22
    case "j": return 0x26
    case "k": return 0x28
    case "l": return 0x25
    case "m": return 0x2E
    case "n": return 0x2D
    case "o": return 0x1F
    case "p": return 0x23
    case "q": return 0x0C
    case "r": return 0x0F
    case "s": return 0x01
    case "t": return 0x11
    case "u": return 0x20
    case "v": return 0x09
    case "w": return 0x0D
    case "x": return 0x07
    case "y": return 0x10
    case "z": return 0x06

    // Digits
    case "0": return 0x1D
    case "1": return 0x12
    case "2": return 0x13
    case "3": return 0x14
    case "4": return 0x15
    case "5": return 0x17
    case "6": return 0x16
    case "7": return 0x1A
    case "8": return 0x1C
    case "9": return 0x19

    // Special Keys
    case "return", "enter": return 0x24
    case "tab": return 0x30
    case "space": return 0x31
    case "delete", "backspace": return 0x33
    case "escape", "esc": return 0x35
    case "forwarddelete": return 0x75

    // Modifiers
    case "command", "meta", "super": return 0x37
    case "shift": return 0x38
    case "capslock": return 0x39
    case "option", "alt": return 0x3A
    case "control", "ctrl": return 0x3B
    case "rightshift": return 0x3C
    case "rightoption", "rightalt": return 0x3D
    case "rightcontrol", "rightctrl": return 0x3E

    // Arrows
    case "arrowleft", "left": return 0x7B
    case "arrowright", "right": return 0x7C
    case "arrowdown", "down": return 0x7D
    case "arrowup", "up": return 0x7E

    // Navigation
    case "home": return 0x73
    case "pageup": return 0x74
    case "end": return 0x77
    case "pagedown": return 0x79

    // Function keys
    case "f1": return 0x7A
    case "f2": return 0x78
    case "f3": return 0x63
    case "f4": return 0x76
    case "f5": return 0x60
    case "f6": return 0x61
    case "f7": return 0x62
    case "f8": return 0x64
    case "f9": return 0x65
    case "f10": return 0x6D
    case "f11": return 0x67
    case "f12": return 0x6F

    default: return nil
    }
  }
}
