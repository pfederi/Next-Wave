import Foundation
import Supabase

/// Stores this device's APNs token in Supabase so the backend can send
/// badge push notifications to it.
actor PushAPI {
    static let shared = PushAPI()
    private init() {}

    private struct TokenRow: Encodable {
        let user_id: String
        let token: String
        let platform: String
    }

    func upsertDeviceToken(_ token: String) async {
        guard let userId = try? await SupabaseManager.shared.ensureSession() else { return }
        let client = SupabaseManager.shared.client
        _ = try? await client
            .from("device_tokens")
            .upsert(TokenRow(user_id: userId.uuidString.lowercased(), token: token, platform: "ios"),
                    onConflict: "user_id,token")
            .execute()
    }
}
