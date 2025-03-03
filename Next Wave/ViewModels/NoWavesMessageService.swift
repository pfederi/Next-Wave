import Foundation

class NoWavesMessageService {
    static let shared = NoWavesMessageService()
    
    private let messages = [
        "No more waves today – back in the lineup tomorrow!",
        "Flat for now, but fresh sets rolling in tomorrow!",
        "Wave machine's off – catch the next swell tomorrow!",
        "Boat's are taking a break – tomorrow's a new ride!",
        "No wake waves left today – time to chill 'til sunrise!",
        "That's it for today – fresh waves incoming tomorrow!",
        "No waves, no worries – time to dry your wetsuit for tomorrow!",
        "The wave train's done for today – ride continues mañana!",
        "Today's waves are history – tomorrow's swell is brewing!",
        "Ship's on pause – fresh rides coming soon!",
        "That's all, folks! But don't worry, tomorrow's a new ride!",
        "No more bumps to ride – but tomorrow's looking rad!",
        "Last wave's gone – time to dream of tomorrow's rides!",
        "Aloha, da waves pau for today – but mo' coming tomorrow!",
        "Chill time, ʻohana! Waves gonna roll in fresh tomorrow!",
        "No more surf – the sea life needs some chill time too!",
        "Post-pumping high is real – but even the ships need a break!",
        "Waves are done, but that post-pumping high lasts all night!",
        "That post-pumping high hits different – but the waves are snoozing now!",
        "No more wake waves, just that sweet post-pumping afterglow!"
    ]
    
    private let noServiceMessages = [
        "No service available at this station",
        "This station is currently not in service",
        "No waves scheduled for this station",
        "This spot is taking a break from the waves",
        "No boats stopping at this station today"
    ]
    
    private var usedMessages: Set<String> = []
    private var usedNoServiceMessages: Set<String> = []
    
    private init() {}
    
    func getMessage() -> String {
        if usedMessages.count >= messages.count {
            // If all messages have been used, reset the used messages
            usedMessages.removeAll()
        }
        
        let availableMessages = messages.filter { !usedMessages.contains($0) }
        let message = availableMessages.randomElement() ?? messages[0]
        usedMessages.insert(message)
        return message
    }
    
    func getNoServiceMessage() -> String {
        if usedNoServiceMessages.count >= noServiceMessages.count {
            // If all messages have been used, reset the used messages
            usedNoServiceMessages.removeAll()
        }
        
        let availableMessages = noServiceMessages.filter { !usedNoServiceMessages.contains($0) }
        let message = availableMessages.randomElement() ?? noServiceMessages[0]
        usedNoServiceMessages.insert(message)
        return message
    }
    
    func reset() {
        usedMessages.removeAll()
        usedNoServiceMessages.removeAll()
    }
} 
