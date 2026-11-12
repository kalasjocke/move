import Foundation

/// Calls `onChange` when the file at `path` changes. Editors often save by
/// writing a new file and renaming it over the old one, so after a rename or
/// delete the watcher opens the path again. If the file is missing, it
/// retries every second.
@MainActor
final class FileWatcher {
    private let path: String
    private let onChange: () -> Void
    private var source: DispatchSourceFileSystemObject?
    private var pending = false

    init(path: String, onChange: @escaping () -> Void) {
        self.path = path
        self.onChange = onChange
    }

    func start() {
        open(notify: false)
    }

    private func open(notify: Bool) {
        // open() follows symlinks, so a config symlinked from dotfiles is
        // watched at its target.
        let fd = Darwin.open(path, O_EVTONLY)
        guard fd >= 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                MainActor.assumeIsolated { self.open(notify: true) }
            }
            return
        }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .delete, .rename],
            queue: .main
        )
        source.setEventHandler { [weak self] in
            MainActor.assumeIsolated {
                self?.handle()
            }
        }
        source.setCancelHandler {
            close(fd)
        }
        source.resume()
        self.source = source

        if notify {
            changed()
        }
    }

    private func handle() {
        guard let source else { return }
        let events = source.data
        if events.contains(.delete) || events.contains(.rename) {
            source.cancel()
            self.source = nil
            // Give the editor a moment to put the new file in place.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                MainActor.assumeIsolated { self.open(notify: true) }
            }
        } else {
            changed()
        }
    }

    /// Coalesces the several events one save can produce into one call.
    private func changed() {
        guard !pending else { return }
        pending = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            MainActor.assumeIsolated {
                self.pending = false
                self.onChange()
            }
        }
    }
}
