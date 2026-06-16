import Testing
import Foundation
@testable import Next_Wave

struct CheckinIdentityTests {

    @Test func anonymousReturnsNilDisplayName() {
        let identity = CheckinIdentity(name: "Pat", isAnonymous: true)
        #expect(identity.displayName == nil)
    }

    @Test func namedReturnsTrimmedName() {
        let identity = CheckinIdentity(name: "  Pat  ", isAnonymous: false)
        #expect(identity.displayName == "Pat")
    }

    @Test func emptyNameIsTreatedAsAnonymous() {
        let identity = CheckinIdentity(name: "   ", isAnonymous: false)
        #expect(identity.displayName == nil)
    }
}
