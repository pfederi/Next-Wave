import Testing
import Foundation
@testable import Next_Wave

struct WeatherInterpolationTests {
    private let steps: [TimeInterval] = [0, 100, 200]   // three forecast steps

    @Test func emptyReturnsNil() {
        #expect(WeatherInterpolation.locate(50, in: []) == nil)
    }

    @Test func midpointHasHalfFraction() {
        let i = WeatherInterpolation.locate(50, in: steps)!
        #expect(i.lowerIndex == 0)
        #expect(i.upperIndex == 1)
        #expect(abs(i.fraction - 0.5) < 1e-9)
        #expect(abs(i.lerp(10, 20) - 15) < 1e-9)
    }

    @Test func quarterPointInterpolatesTemperature() {
        let i = WeatherInterpolation.locate(25, in: steps)!
        #expect(abs(i.fraction - 0.25) < 1e-9)
        #expect(abs(i.lerp(10, 20) - 12.5) < 1e-9)
    }

    @Test func clampsBeforeFirst() {
        let i = WeatherInterpolation.locate(-50, in: steps)!
        #expect(i.lowerIndex == 0 && i.upperIndex == 0)
        #expect(i.lerp(10, 99) == 10)   // fraction 0 → lower value
    }

    @Test func clampsAfterLast() {
        let i = WeatherInterpolation.locate(500, in: steps)!
        #expect(i.lowerIndex == 2 && i.upperIndex == 2)
        #expect(i.fraction == 0)
    }

    @Test func singlePointAlwaysClamps() {
        let i = WeatherInterpolation.locate(123, in: [42])!
        #expect(i.lowerIndex == 0 && i.upperIndex == 0 && i.fraction == 0)
    }

    @Test func nearestIndexPicksCloserStep() {
        let near0 = WeatherInterpolation.locate(40, in: steps)!   // fraction 0.4 → lower
        let near1 = WeatherInterpolation.locate(60, in: steps)!   // fraction 0.6 → upper
        #expect(near0.nearestIndex == 0)
        #expect(near1.nearestIndex == 1)
    }
}
