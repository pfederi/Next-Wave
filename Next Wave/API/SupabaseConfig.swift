import Foundation

enum SupabaseConfig {
    // Self-hosted Supabase (same instance as promo tiles).
    static let url = URL(string: "https://nextwaveapp.db.lakeshorestudios.ch")!
    // Public anon key — safe to ship; writes are constrained by RLS.
    static let anonKey = "eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJpc3MiOiJzdXBhYmFzZSIsImlhdCI6MTc3MzIyMjMwMCwiZXhwIjo0OTI4ODk1OTAwLCJyb2xlIjoiYW5vbiJ9.grHX8Y9WcO08HrvamEgUpfcDvYJmjo6thF3rL9-wD3Y"
}
