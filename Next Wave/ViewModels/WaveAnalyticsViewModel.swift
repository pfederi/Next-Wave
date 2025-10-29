import Foundation

class WaveAnalyticsViewModel: ObservableObject {
    @Published var spotAnalytics: [SpotAnalytics] = []
    private let maxWaveGap: TimeInterval = 3600 // 1 hour max between waves
    private let minSessionDuration: TimeInterval = 3600 // minimum 1 hour session
    private let maxSessionDuration: TimeInterval = 7200 // maximum 2 hour session
    
    func analyzeWaves(_ waves: [WaveEvent], for spotId: String, spotName: String) {
        Task {
            var timeSlots: [WaveTimeSlot] = []
            let sortedWaves = waves.sorted { $0.time < $1.time }
            
            guard !sortedWaves.isEmpty else { return }
            
            // Get sun times for the day
            let sunTimes = try? await SunTimeService.shared.getSunTimes(date: sortedWaves[0].time)
            
            // Only analyze if we have enough time for a session
            let totalDuration = sortedWaves.last!.time.timeIntervalSince(sortedWaves[0].time)
            guard totalDuration >= minSessionDuration else { return }
            
            for startWave in sortedWaves {
                var sessionWaves: [WaveEvent] = []
                var lastWaveTime = startWave.time
                
                // Find waves that form a good session starting from this wave
                for wave in sortedWaves where wave.time >= startWave.time {
                    let timeSinceLastWave = wave.time.timeIntervalSince(lastWaveTime)
                    let totalSessionTime = wave.time.timeIntervalSince(startWave.time)
                    
                    // Stop if gap is too large or session would be too long
                    if timeSinceLastWave > maxWaveGap || totalSessionTime > maxSessionDuration {
                        break
                    }
                    
                    sessionWaves.append(wave)
                    lastWaveTime = wave.time
                }
                
                // Only consider sessions with minimum duration and at least 3 waves
                let sessionDuration = lastWaveTime.timeIntervalSince(startWave.time)
                if sessionDuration >= minSessionDuration && sessionWaves.count >= 3 {
                    let timeSlot = WaveTimeSlot(
                        startTime: startWave.time,
                        endTime: lastWaveTime,
                        waveCount: sessionWaves.count,
                        waves: sessionWaves
                    )
                    
                    // Calculate session score based on waves per hour and daylight
                    let score = calculateSessionScore(timeSlot, sunTimes: sunTimes)
                    if score > 0 {
                        timeSlots.append(timeSlot)
                    }
                }
            }
            
            // Sort by session score
            timeSlots.sort { slot1, slot2 in
                calculateSessionScore(slot1, sunTimes: sunTimes) > calculateSessionScore(slot2, sunTimes: sunTimes)
            }
            
            // Take top 5 best sessions
            let bestSlots = Array(timeSlots.prefix(5))
            
            let analytics = SpotAnalytics(
                spotId: spotId,
                spotName: spotName,
                timeSlots: bestSlots
            )
            
            await MainActor.run {
                if let index = self.spotAnalytics.firstIndex(where: { $0.spotId == spotId }) {
                    self.spotAnalytics[index] = analytics
                } else {
                    self.spotAnalytics.append(analytics)
                }
            }
        }
    }
    
    private func calculateSessionScore(_ slot: WaveTimeSlot, sunTimes: SunTimes?) -> Double {
        // Berechne Qualitätsscore basierend auf Schiffstypen (wichtigster Faktor)
        let qualityScore = calculateWaveQualityScore(for: slot.waves)
        
        // Frequenz-Bonus: Mehr Wellen pro Stunde ist besser, aber weniger wichtig
        let frequencyBonus = 1.0 + (slot.wavesPerHour / 10.0) // Max ~1.5x bei 5 Wellen/Stunde
        
        var score = qualityScore * frequencyBonus
        
        if let sunTimes = sunTimes {
            // Check if session overlaps with twilight periods
            let twilightOverlap = calculateTwilightOverlap(slot, sunTimes: sunTimes)
            
            // Penalize sessions based on twilight overlap
            if twilightOverlap > 0 {
                // Reduce score based on percentage of session in twilight
                score *= (1.0 - (twilightOverlap * 0.8)) // 80% penalty for full twilight overlap
            }
            
            // Completely exclude sessions that are entirely in darkness
            if isSessionInDarkness(slot, sunTimes: sunTimes) {
                return 0
            }
        }
        
        return score
    }
    
    private func calculateWaveQualityScore(for waves: [WaveEvent]) -> Double {
        guard !waves.isEmpty else { return 0.0 }
        
        var totalScore = 0.0
        
        for wave in waves {
            guard let shipName = wave.shipName else {
                // Wellen ohne Schiffsnamen bekommen minimalen Score
                totalScore += 1.0
                continue
            }
            
            let cleanName = shipName.trimmingCharacters(in: .whitespaces)
            
            // 3-Wellen Schiffe (beste Qualität) - sehr hoher Score
            if ["MS Panta Rhei", "MS Albis", "EMS Uetliberg", "EMS Pfannenstiel", "EM Uetliberg", "EM Pfannenstiel"].contains(cleanName) {
                totalScore += 10.0
            }
            // 2-Wellen Schiffe (mittlere Qualität) - mittlerer Score
            else if ["MS Wädenswil", "MS Limmat", "MS Helvetia", "MS Linth", "DS Stadt Zürich", "DS Stadt Rapperswil"].contains(cleanName) {
                totalScore += 5.0
            }
            // 1-Wellen Schiffe (Standard) - niedriger Score
            else {
                totalScore += 2.0
            }
        }
        
        return totalScore
    }
    
    private func calculateTwilightOverlap(_ slot: WaveTimeSlot, sunTimes: SunTimes) -> Double {
        let sessionDuration = slot.duration
        var overlapDuration: TimeInterval = 0
        
        // Morning twilight overlap
        if slot.startTime <= sunTimes.sunrise {
            let overlapEnd = min(slot.endTime, sunTimes.sunrise)
            let morningOverlap = overlapEnd.timeIntervalSince(slot.startTime)
            overlapDuration += max(0, morningOverlap)
        }
        
        // Evening twilight overlap
        if slot.endTime >= sunTimes.sunset {
            let overlapStart = max(slot.startTime, sunTimes.sunset)
            let eveningOverlap = slot.endTime.timeIntervalSince(overlapStart)
            overlapDuration += max(0, eveningOverlap)
        }
        
        return overlapDuration / sessionDuration // Returns percentage of session in twilight
    }
    
    private func isSessionInDarkness(_ slot: WaveTimeSlot, sunTimes: SunTimes) -> Bool {
        // Session is before sunrise or after sunset
        return slot.endTime <= sunTimes.civilTwilightBegin || slot.startTime >= sunTimes.civilTwilightEnd
    }
}

private extension Calendar {
    func startOfHour(for date: Date) -> Date {
        let components = dateComponents([.year, .month, .day, .hour], from: date)
        return self.date(from: components) ?? date
    }
} 