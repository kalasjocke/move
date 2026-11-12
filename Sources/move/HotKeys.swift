import Carbon.HIToolbox
import MoveCore

/// Registers global hotkeys with Carbon and calls `onPress` with the frame
/// bound to the pressed shortcut. Carbon delivers the events on the main
/// thread through the application event target.
@MainActor
final class HotKeys {
    private let onPress: (Frame) -> Void
    private var refs: [EventHotKeyRef] = []
    private var frames: [UInt32: Frame] = [:]
    private var nextID: UInt32 = 1
    private var handler: EventHandlerRef?

    /// 'MOVE' as a four-character code.
    private let signature: OSType = 0x4D4F_5645

    init(onPress: @escaping (Frame) -> Void) {
        self.onPress = onPress
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return OSStatus(eventNotHandledErr) }
                var id = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &id
                )
                guard status == noErr else { return status }
                let pointer = UInt(bitPattern: userData)
                let hotKeyID = id.id
                MainActor.assumeIsolated {
                    let hotKeys = Unmanaged<HotKeys>
                        .fromOpaque(UnsafeRawPointer(bitPattern: pointer)!)
                        .takeUnretainedValue()
                    hotKeys.pressed(hotKeyID)
                }
                return noErr
            },
            1,
            &spec,
            Unmanaged.passUnretained(self).toOpaque(),
            &handler
        )
        if status != noErr {
            log("could not install the hotkey handler (status \(status))")
        }
    }

    /// Replaces all registered hotkeys with these bindings.
    func set(_ bindings: [Binding]) {
        for ref in refs {
            UnregisterEventHotKey(ref)
        }
        refs = []
        frames = [:]

        for binding in bindings {
            let id = EventHotKeyID(signature: signature, id: nextID)
            nextID += 1
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                binding.shortcut.key,
                binding.shortcut.modifiers.rawValue,
                id,
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref {
                refs.append(ref)
                frames[id.id] = binding.frame
            } else if status == eventHotKeyExistsErr {
                log("\(binding.text): another app already uses this shortcut")
            } else {
                log("\(binding.text): could not register the shortcut (status \(status))")
            }
        }
    }

    private func pressed(_ id: UInt32) {
        if let frame = frames[id] {
            onPress(frame)
        }
    }
}
