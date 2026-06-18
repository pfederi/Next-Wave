import Foundation

enum GPXParseError: Error, Equatable {
    case noTrackPoints
}

enum GPXParser {
    static func parse(url: URL) throws -> GPXSession {
        try parse(data: Data(contentsOf: url))
    }

    static func parse(data: Data) throws -> GPXSession {
        let delegate = Delegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        guard !delegate.points.isEmpty else { throw GPXParseError.noTrackPoints }
        let meta = GPXMetadata(name: delegate.metaName, desc: delegate.metaDesc,
                               creator: delegate.creator, startTime: delegate.metaTime)
        return GPXSession(metadata: meta, points: delegate.points)
    }

    private final class Delegate: NSObject, XMLParserDelegate {
        private static let iso: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return f
        }()
        private static let isoNoFrac: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()
        static func date(_ s: String) -> Date? { iso.date(from: s) ?? isoNoFrac.date(from: s) }

        var creator: String?
        var metaName: String?, metaDesc: String?, metaTime: Date?
        var points: [GPXPoint] = []

        private var inMetadata = false
        private var curLat = 0.0, curLon = 0.0
        private var curEle: Double?, curSpeed: Double?, curDist: Double?, curTime: Date?
        private var text = ""

        func parser(_ p: XMLParser, didStartElement el: String, namespaceURI: String?,
                    qualifiedName: String?, attributes a: [String: String]) {
            text = ""
            switch el {
            case "gpx": creator = a["creator"]
            case "metadata": inMetadata = true
            case "trkpt":
                curLat = Double(a["lat"] ?? "") ?? 0
                curLon = Double(a["lon"] ?? "") ?? 0
                curEle = nil; curSpeed = nil; curDist = nil; curTime = nil
            default: break
            }
        }

        func parser(_ p: XMLParser, foundCharacters s: String) { text += s }

        func parser(_ p: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName: String?) {
            let v = text.trimmingCharacters(in: .whitespacesAndNewlines)
            switch el {
            case "metadata": inMetadata = false
            case "name" where inMetadata: metaName = v
            case "desc" where inMetadata: metaDesc = v
            case "time" where inMetadata: metaTime = Delegate.date(v)
            case "ele": curEle = Double(v)
            case "speed": curSpeed = Double(v)
            case "distance": curDist = Double(v)
            case "time" where !inMetadata: curTime = Delegate.date(v)
            case "trkpt":
                if let t = curTime {
                    points.append(GPXPoint(time: t, lat: curLat, lon: curLon,
                                           ele: curEle, speed: curSpeed, cumulativeDistance: curDist))
                }
            default: break
            }
        }
    }
}
