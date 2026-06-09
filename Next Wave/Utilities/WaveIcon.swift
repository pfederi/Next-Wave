import Foundation

/// Maps a ship name to its wave-strength asset name ("waves1" | "waves2" | "waves3").
enum WaveIcon {
    static func name(for shipName: String) -> String {
        let cleanName = shipName.trimmingCharacters(in: .whitespaces)
        switch cleanName {
        case "MS Panta Rhei", "MS Albis", "EMS Uetliberg", "EMS Pfannenstiel", "EM Uetliberg", "EM Pfannenstiel":
            return "waves3"
        case "MS Wädenswil", "MS Limmat", "MS Helvetia", "MS Linth", "DS Stadt Zürich", "DS Stadt Rapperswil":
            return "waves2"
        default:
            return "waves1"
        }
    }
}
