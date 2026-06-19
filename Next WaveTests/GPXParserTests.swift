import Testing
import Foundation
@testable import Next_Wave

struct GPXParserTests {
    private let sample = """
    <?xml version="1.0" encoding="UTF-8"?>
    <gpx version="1.1" creator="FoilMotion" xmlns="http://www.topografix.com/GPX/1/1">
      <metadata><name>Test</name><desc>1 run</desc><time>2025-09-18T15:48:52Z</time></metadata>
      <trk><trkseg>
        <trkpt lat="47.3110" lon="8.5571"><ele>406.6</ele><time>2025-09-18T15:49:09Z</time>
          <extensions><TrackPointExtension><distance>0.00</distance><speed>0.05</speed></TrackPointExtension></extensions>
        </trkpt>
        <trkpt lat="47.3112" lon="8.5573"><ele>406.7</ele><time>2025-09-18T15:49:10Z</time>
          <extensions><TrackPointExtension><distance>5.00</distance><speed>4.20</speed></TrackPointExtension></extensions>
        </trkpt>
      </trkseg></trk>
    </gpx>
    """

    @Test func parsesPointsAndExtensions() throws {
        let s = try GPXParser.parse(data: Data(sample.utf8))
        #expect(s.points.count == 2)
        #expect(s.metadata.creator == "FoilMotion")
        #expect(abs(s.points[0].lat - 47.3110) < 1e-6)
        #expect(s.points[1].speed == 4.20)
        #expect(s.points[1].cumulativeDistance == 5.00)
    }

    @Test func throwsWhenNoTrackPoints() {
        let empty = "<gpx><trk><trkseg></trkseg></trk></gpx>"
        #expect(throws: GPXParseError.self) { try GPXParser.parse(data: Data(empty.utf8)) }
    }
}
