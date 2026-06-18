import SwiftUI

/// Untappd-style circular badge medallion: a category-colored ring, a cream rim,
/// the category illustration, and a greyscale + lock treatment when not yet earned.
/// Renders only the badge graphic — no title or caption.
struct BadgeMedalView: View {
    let badge: Badge
    let isEarned: Bool
    var size: CGFloat = 96

    private static let cream = Color(badgeHex: "#F3E6C9")

    var body: some View {
        ZStack {
            // Category-colored ring
            Circle().fill(badge.category.ringColor)

            // Cream rim
            Circle()
                .fill(Self.cream)
                .padding(size * 0.045)

            // Illustration (greyscaled when locked)
            illustration
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .padding(size * 0.075)
                .grayscale(isEarned ? 0 : 1)

            // Locked overlay
            if !isEarned {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.72))
                        .frame(width: size * 0.44, height: size * 0.44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundColor(Color(white: 0.23))
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: size * 0.04, x: 0, y: size * 0.02)
        .accessibilityElement()
        .accessibilityLabel(Text(isEarned ? badge.title : "\(badge.title), locked"))
    }

    /// Asset name for this badge's illustration. Season badges have individual
    /// images; every other badge uses its category image.
    private var assetName: String {
        switch badge.id {
        case "season_spring": return "badge_spring"
        case "season_summer": return "badge_summer"
        case "season_autumn": return "badge_autumn"
        case "season_winter": return "badge_winter"
        case "four_seasons":  return "badge_fourseasons"
        default:              return badge.category.imageName
        }
    }

    @ViewBuilder
    private var illustration: some View {
        if UIImage(named: assetName) != nil {
            Image(assetName)
                .resizable()
        } else {
            // Placeholder until the category artwork is added to the asset catalog.
            LinearGradient(
                colors: [badge.category.ringColor.opacity(0.22), badge.category.ringColor.opacity(0.55)],
                startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }
}

extension BadgeCategory {
    /// Ring color per category (matches the Figma "Badge Categories" variables).
    var ringColor: Color {
        switch self {
        case .milestone:   return Color(badgeHex: "#1E88E5")
        case .stations:    return Color(badgeHex: "#26A69A")
        case .lakes:       return Color(badgeHex: "#43A047")
        case .loyalty:     return Color(badgeHex: "#FB8C00")
        case .firstShip:   return Color(badgeHex: "#FF7043")
        case .lastShip:    return Color(badgeHex: "#8E24AA")
        case .timeOfDay:   return Color(badgeHex: "#5C6BC0")
        case .weekend:     return Color(badgeHex: "#EC407A")
        case .seasons:     return Color(badgeHex: "#00897B")
        case .sameDay:     return Color(badgeHex: "#00ACC1")
        case .anniversary: return Color(badgeHex: "#F9A825")
        case .social:      return Color(badgeHex: "#E53935")
        case .streak:      return Color(badgeHex: "#F4511E")
        }
    }

    /// Asset-catalog name for the category illustration (one image per category).
    var imageName: String { "badge_\(rawValue.lowercased())" }
}

private extension Color {
    init(badgeHex hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        self.init(
            red: Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8) / 255,
            blue: Double(v & 0x0000FF) / 255)
    }
}
