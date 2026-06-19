import UIKit
import UniformTypeIdentifiers

/// Minimal, UI-less Share Extension: it grabs the shared GPX, copies it into the
/// shared App Group container, then opens the host app via `nextwave://import-gpx`
/// so the main app can run the verified-rides import and show its summary.
final class ShareViewController: UIViewController {
    private static let appGroup = "group.com.federi.Next-Wave"
    private static let acceptedTypes = ["com.topografix.gpx", "public.xml", "public.data"]

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        handleShare()
    }

    private func handleShare() {
        guard let item = extensionContext?.inputItems.first as? NSExtensionItem,
              let attachment = item.attachments?.first(where: { att in
                  Self.acceptedTypes.contains { att.hasItemConformingToTypeIdentifier($0) }
              }),
              let typeID = Self.acceptedTypes.first(where: { attachment.hasItemConformingToTypeIdentifier($0) })
        else { return finish() }

        attachment.loadItem(forTypeIdentifier: typeID, options: nil) { [weak self] data, _ in
            guard let self else { return }
            let fileURL: URL?
            switch data {
            case let url as URL:
                fileURL = self.copyIntoSharedContainer(from: url, data: nil)
            case let raw as Data:
                fileURL = self.copyIntoSharedContainer(from: nil, data: raw)
            default:
                fileURL = nil
            }
            if let fileURL { self.openHostApp(name: fileURL.lastPathComponent) }
            self.finish()
        }
    }

    /// Copy/write the GPX into <appgroup>/GPXInbox/<uuid>.gpx. Returns the new URL.
    private func copyIntoSharedContainer(from url: URL?, data: Data?) -> URL? {
        let fm = FileManager.default
        guard let container = fm.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else { return nil }
        let inbox = container.appendingPathComponent("GPXInbox", isDirectory: true)
        try? fm.createDirectory(at: inbox, withIntermediateDirectories: true)
        let dest = inbox.appendingPathComponent(UUID().uuidString).appendingPathExtension("gpx")
        do {
            if let url {
                let access = url.startAccessingSecurityScopedResource()
                defer { if access { url.stopAccessingSecurityScopedResource() } }
                if fm.fileExists(atPath: dest.path) { try? fm.removeItem(at: dest) }
                try fm.copyItem(at: url, to: dest)
            } else if let data {
                try data.write(to: dest)
            } else {
                return nil
            }
            return dest
        } catch {
            return nil
        }
    }

    /// Open the containing app via the custom URL scheme (responder-chain trick,
    /// since UIApplication.open is unavailable to extensions).
    private func openHostApp(name: String) {
        guard let escaped = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "nextwave://import-gpx?name=\(escaped)") else { return }
        var responder: UIResponder? = self
        let selector = NSSelectorFromString("openURL:")
        while let r = responder {
            if r.responds(to: selector) {
                r.perform(selector, with: url)
                break
            }
            responder = r.next
        }
    }

    private func finish() {
        extensionContext?.completeRequest(returningItems: [], completionHandler: nil)
    }
}
