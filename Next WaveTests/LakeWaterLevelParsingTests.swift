import Testing
@testable import Next_Wave

struct LakeWaterLevelParsingTests {
    @Test func parsesValueWithUnit() {
        #expect(Lake.parseLevelMeters(from: "405.96 m.ü.M.") == 405.96)
    }

    @Test func returnsNilForEmptyString() {
        #expect(Lake.parseLevelMeters(from: "") == nil)
    }

    @Test func returnsNilForNonNumericPrefix() {
        #expect(Lake.parseLevelMeters(from: "n/a m.ü.M.") == nil)
    }
}
