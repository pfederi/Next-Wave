import SwiftUI

struct BadgeMedalView: View {
    let imageName: String
    let ringColor: Color
    let isEarned: Bool
    let verified: Bool
    var size: CGFloat = 96

    private static let cream = Color(badgeHex: "#F3E6C9")

    /// Unverified badge (existing call sites).
    init(badge: Badge, isEarned: Bool, size: CGFloat = 96) {
        self.imageName = BadgeMedalView.assetName(for: badge)
        self.ringColor = badge.category.ringColor
        self.isEarned = isEarned
        self.verified = false
        self.size = size
    }

    /// Verified badge.
    init(imageName: String, ringColor: Color, isEarned: Bool, verified: Bool = true, size: CGFloat = 96) {
        self.imageName = imageName
        self.ringColor = ringColor
        self.isEarned = isEarned
        self.verified = verified
        self.size = size
    }

    private static func assetName(for badge: Badge) -> String {
        switch badge.id {
        case "season_spring": return "badge_spring"
        case "season_summer": return "badge_summer"
        case "season_autumn": return "badge_autumn"
        case "season_winter": return "badge_winter"
        case "four_seasons":  return "badge_fourseasons"
        case "lone_wolf":     return "badge_lonewolf"
        default:              return badge.category.imageName
        }
    }

    var body: some View {
        ZStack {
            Circle().fill(ringColor)
            Circle().fill(Self.cream).padding(size * 0.045)
            illustration
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .padding(size * 0.075)
                .grayscale(isEarned ? 0 : 1)
            if !isEarned {
                ZStack {
                    Circle().fill(Color.white.opacity(0.72)).frame(width: size * 0.44, height: size * 0.44)
                    Image(systemName: "lock.fill")
                        .font(.system(size: size * 0.22, weight: .bold))
                        .foregroundColor(Color(white: 0.23))
                }
            }
            if verified {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: size * 0.24))
                    .foregroundColor(.white)
                    .background(Circle().fill(Color.green).frame(width: size * 0.24, height: size * 0.24))
                    .position(x: size * 0.84, y: size * 0.16)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.18), radius: size * 0.04, x: 0, y: size * 0.02)
        .accessibilityElement()
        .accessibilityLabel(Text(verified ? "Verified badge" : (isEarned ? "Earned badge" : "Locked badge")))
    }

    @ViewBuilder
    private var illustration: some View {
        if UIImage(named: imageName) != nil {
            Image(imageName).resizable()
        } else {
            LinearGradient(colors: [ringColor.opacity(0.22), ringColor.opacity(0.55)],
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
    /// Parses a 6-digit "#RRGGBB" hex. Falls back to a neutral gray on malformed input.
    init(badgeHex hex: String) {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        guard s.count == 6, Scanner(string: s).scanHexInt64(&v) else {
            self = .gray
            return
        }
        self.init(
            red: Double((v & 0xFF0000) >> 16) / 255,
            green: Double((v & 0x00FF00) >> 8) / 255,
            blue: Double(v & 0x0000FF) / 255)
    }
}

#if DEBUG
#Preview("Badges — earned") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
            ForEach(BadgeCatalog.all.prefix(8).map { $0 }) { badge in
                VStack(spacing: 10) {
                    BadgeMedalView(badge: badge, isEarned: true, size: 120)
                    Text(badge.title).font(.headline)
                }
            }
        }
        .padding()
    }
}

#Preview("Badges — locked") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 24) {
            ForEach(BadgeCatalog.all.prefix(8).map { $0 }) { badge in
                VStack(spacing: 10) {
                    BadgeMedalView(badge: badge, isEarned: false, size: 120)
                    Text(badge.title).font(.headline).foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
}
#endif
