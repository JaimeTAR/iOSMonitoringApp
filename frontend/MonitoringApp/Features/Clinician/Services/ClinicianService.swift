import Foundation
import Supabase

/// Centralized data-access layer for all clinician-specific Supabase queries
final class ClinicianService: ClinicianServiceProtocol {

    // MARK: - Patient Data

    func fetchPatients(for clinicianId: UUID) async throws -> [PatientSummary] {
        do {
            // 1. Get active relationships
            let relationships: [ClinicianPatient] = try await supabase
                .from("clinician_patients")
                .select()
                .eq("clinician_id", value: clinicianId)
                .eq("status", value: RelationshipStatus.activo.rawValue)
                .execute()
                .value

            let activeRelationships = relationships.filter { $0.endDate == nil }
            guard !activeRelationships.isEmpty else { return [] }

            let patientIds = activeRelationships.map { $0.patientId }

            // 2. Fetch profiles
            let profiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .in("user_id", values: patientIds)
                .execute()
                .value

            // 3. Fetch recent samples (last 14 days for trend computation)
            let now = Date()
            let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!
            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .in("user_id", values: patientIds)
                .gte("window_start", value: ISO8601DateFormatter().string(from: fourteenDaysAgo))
                .order("window_start", ascending: false)
                .execute()
                .value

            // 4. Build summaries
            let samplesByPatient = Dictionary(grouping: samples, by: { $0.userId })
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })

            return patientIds.compactMap { patientId -> PatientSummary? in
                guard let profile = profileMap[patientId] else { return nil }
                let patientSamples = samplesByPatient[patientId] ?? []
                let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

                let recent7d = patientSamples.filter { $0.windowStart >= sevenDaysAgo }
                let prior7d = patientSamples.filter { $0.windowStart < sevenDaysAgo }

                let avgHR7d = recent7d.isEmpty ? nil : recent7d.map(\.avgHeartRate).reduce(0, +) / Double(recent7d.count)
                let avgRMSSD7d: Double? = {
                    let vals = recent7d.compactMap(\.rmssd)
                    return vals.isEmpty ? nil : vals.reduce(0, +) / Double(vals.count)
                }()

                let trend = Self.computeTrend(recent: recent7d, prior: prior7d)
                let lastActive = patientSamples.first?.windowStart

                return PatientSummary(
                    id: patientId,
                    name: profile.name ?? "Unknown",
                    lastActiveDate: lastActive,
                    avgHeartRate7d: avgHR7d,
                    avgRMSSD7d: avgRMSSD7d,
                    trend: trend
                )
            }
        } catch let error as ClinicianError {
            throw error
        } catch {
            throw ClinicianError.fetchPatientsFailed(error.localizedDescription)
        }
    }

    func fetchPatientDetail(patientId: UUID) async throws -> PatientDetail {
        do {
            let profile: UserProfile = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: patientId)
                .single()
                .execute()
                .value

            let now = Date()
            let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!

            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .eq("user_id", value: patientId)
                .gte("window_start", value: ISO8601DateFormatter().string(from: sevenDaysAgo))
                .order("window_start", ascending: true)
                .execute()
                .value

            let overview: PatientOverview? = samples.isEmpty ? nil : Self.buildOverview(from: samples)

            return PatientDetail(profile: profile, overview: overview)
        } catch let error as ClinicianError {
            throw error
        } catch {
            throw ClinicianError.fetchPatientsFailed(error.localizedDescription)
        }
    }

    func fetchPatientSamples(patientId: UUID, from startDate: Date, to endDate: Date) async throws -> [PhysiologicalSample] {
        do {
            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .eq("user_id", value: patientId)
                .gte("window_start", value: ISO8601DateFormatter().string(from: startDate))
                .lte("window_start", value: ISO8601DateFormatter().string(from: endDate))
                .order("window_start", ascending: true)
                .execute()
                .value
            return samples
        } catch {
            throw ClinicianError.fetchSamplesFailed(error.localizedDescription)
        }
    }

    // MARK: - Dashboard

    func fetchDashboardStats(for clinicianId: UUID) async throws -> DashboardStats {
        do {
            // Active relationships
            let relationships: [ClinicianPatient] = try await supabase
                .from("clinician_patients")
                .select()
                .eq("clinician_id", value: clinicianId)
                .eq("status", value: RelationshipStatus.activo.rawValue)
                .execute()
                .value

            let activePatientIds = relationships.filter { $0.endDate == nil }.map { $0.patientId }
            let totalActive = activePatientIds.count

            // Patients active today (sample in last 24h)
            var patientsActiveToday = 0
            if !activePatientIds.isEmpty {
                let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
                let recentSamples: [PhysiologicalSample] = try await supabase
                    .from("physiological_samples")
                    .select()
                    .in("user_id", values: activePatientIds)
                    .gte("window_start", value: ISO8601DateFormatter().string(from: twentyFourHoursAgo))
                    .execute()
                    .value

                let distinctPatients = Set(recentSamples.map { $0.userId })
                patientsActiveToday = distinctPatients.count
            }

            // Pending invitations
            let invitations: [InvitationCode] = try await supabase
                .from("clinician_invitation_codes")
                .select()
                .eq("clinician_id", value: clinicianId)
                .eq("status", value: InvitationStatus.pending.rawValue)
                .execute()
                .value

            return DashboardStats(
                totalActivePatients: totalActive,
                patientsActiveToday: patientsActiveToday,
                pendingInvitations: invitations.count
            )
        } catch let error as ClinicianError {
            throw error
        } catch {
            throw ClinicianError.fetchPatientsFailed(error.localizedDescription)
        }
    }

    func fetchNeedsAttention(for clinicianId: UUID) async throws -> [NeedsAttentionItem] {
        do {
            let relationships: [ClinicianPatient] = try await supabase
                .from("clinician_patients")
                .select()
                .eq("clinician_id", value: clinicianId)
                .eq("status", value: RelationshipStatus.activo.rawValue)
                .execute()
                .value

            let activePatientIds = relationships.filter { $0.endDate == nil }.map { $0.patientId }
            guard !activePatientIds.isEmpty else { return [] }

            let profiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .in("user_id", values: activePatientIds)
                .execute()
                .value

            let now = Date()
            let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!

            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .in("user_id", values: activePatientIds)
                .gte("window_start", value: ISO8601DateFormatter().string(from: fourteenDaysAgo))
                .execute()
                .value

            let samplesByPatient = Dictionary(grouping: samples, by: { $0.userId })
            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })

            return Self.classifyNeedsAttention(
                patientIds: activePatientIds,
                profiles: profileMap,
                samplesByPatient: samplesByPatient,
                now: now
            )
        } catch let error as ClinicianError {
            throw error
        } catch {
            throw ClinicianError.fetchPatientsFailed(error.localizedDescription)
        }
    }

    func fetchRecentActivity(for clinicianId: UUID, limit: Int) async throws -> [RecentActivityItem] {
        do {
            let relationships: [ClinicianPatient] = try await supabase
                .from("clinician_patients")
                .select()
                .eq("clinician_id", value: clinicianId)
                .eq("status", value: RelationshipStatus.activo.rawValue)
                .execute()
                .value

            let activePatientIds = relationships.filter { $0.endDate == nil }.map { $0.patientId }
            guard !activePatientIds.isEmpty else { return [] }

            let profiles: [UserProfile] = try await supabase
                .from("user_profile")
                .select()
                .in("user_id", values: activePatientIds)
                .execute()
                .value

            let profileMap = Dictionary(uniqueKeysWithValues: profiles.map { ($0.userId, $0) })

            // Fetch recent samples across all patients
            let samples: [PhysiologicalSample] = try await supabase
                .from("physiological_samples")
                .select()
                .in("user_id", values: activePatientIds)
                .order("window_start", ascending: false)
                .limit(limit * 20) // fetch extra to group into sessions
                .execute()
                .value

            // Group samples into sessions per patient, then pick the most recent sessions
            let samplesByPatient = Dictionary(grouping: samples, by: { $0.userId })
            var allSessions: [RecentActivityItem] = []

            for (patientId, patientSamples) in samplesByPatient {
                let patientName = profileMap[patientId]?.name ?? "Unknown"
                let sorted = patientSamples.sorted { $0.windowStart < $1.windowStart }
                let sessions = Self.groupIntoSessions(sorted)

                for session in sessions {
                    guard let first = session.first, let last = session.last else { continue }
                    let avgHR = session.map(\.avgHeartRate).reduce(0, +) / Double(session.count)
                    let durationMinutes = max(1, session.count)

                    allSessions.append(RecentActivityItem(
                        id: first.id,
                        patientId: patientId,
                        patientName: patientName,
                        sessionDate: last.windowStart,
                        durationMinutes: durationMinutes,
                        avgHeartRate: avgHR
                    ))
                }
            }

            // Sort by most recent and take the limit
            return Array(allSessions.sorted { $0.sessionDate > $1.sessionDate }.prefix(limit))
        } catch let error as ClinicianError {
            throw error
        } catch {
            throw ClinicianError.fetchPatientsFailed(error.localizedDescription)
        }
    }

    // MARK: - Patient Updates

    func updatePatientRestingHeartRate(patientId: UUID, bpm: Double) async throws {
        do {
            try await supabase
                .from("user_profile")
                .update(["resting_heart_rate": bpm])
                .eq("user_id", value: patientId)
                .execute()
        } catch {
            throw ClinicianError.updateRestingHRFailed(error.localizedDescription)
        }
    }

    // MARK: - Invitations

    func fetchInvitationCodes(for clinicianId: UUID) async throws -> [InvitationCode] {
        do {
            let codes: [InvitationCode] = try await supabase
                .from("clinician_invitation_codes")
                .select()
                .eq("clinician_id", value: clinicianId)
                .order("created_at", ascending: false)
                .execute()
                .value
            return codes
        } catch {
            throw ClinicianError.fetchInvitationsFailed(error.localizedDescription)
        }
    }

    func generateInvitationCode(for clinicianId: UUID) async throws -> InvitationCode {
        do {
            let now = Date()
            let expiresAt = Calendar.current.date(byAdding: .day, value: 7, to: now)!
            let code = Self.generateRandomCode(length: 5)

            let insert = InvitationCodeInsert(
                clinicianId: clinicianId,
                code: code,
                status: .pending,
                createdAt: now,
                expiresAt: expiresAt
            )

            let created: InvitationCode = try await supabase
                .from("clinician_invitation_codes")
                .insert(insert)
                .select()
                .single()
                .execute()
                .value

            return created
        } catch {
            throw ClinicianError.generateCodeFailed(error.localizedDescription)
        }
    }

    func revokeInvitationCode(id: UUID) async throws {
        do {
            try await supabase
                .from("clinician_invitation_codes")
                .update(["status": InvitationStatus.revoked.rawValue])
                .eq("id", value: id)
                .execute()
        } catch {
            throw ClinicianError.revokeCodeFailed(error.localizedDescription)
        }
    }

    // MARK: - Profile

    func fetchClinicianProfile(userId: UUID) async throws -> UserProfile {
        do {
            let profile: UserProfile = try await supabase
                .from("user_profile")
                .select()
                .eq("user_id", value: userId)
                .single()
                .execute()
                .value
            return profile
        } catch {
            throw ClinicianError.profileNotFound
        }
    }

    // MARK: - Helpers

    /// Computes health trend by comparing recent 7d vs prior 7d samples
    static func computeTrend(recent: [PhysiologicalSample], prior: [PhysiologicalSample]) -> HealthTrend {
        guard !recent.isEmpty, !prior.isEmpty else { return .stable }

        let recentAvgHR = recent.map(\.avgHeartRate).reduce(0, +) / Double(recent.count)
        let priorAvgHR = prior.map(\.avgHeartRate).reduce(0, +) / Double(prior.count)

        let recentRMSSD = recent.compactMap(\.rmssd)
        let priorRMSSD = prior.compactMap(\.rmssd)

        // HR change
        let hrChange = priorAvgHR > 0 ? (recentAvgHR - priorAvgHR) / priorAvgHR : 0

        // RMSSD change
        var rmssdChange: Double = 0
        if !recentRMSSD.isEmpty, !priorRMSSD.isEmpty {
            let avgRecentRMSSD = recentRMSSD.reduce(0, +) / Double(recentRMSSD.count)
            let avgPriorRMSSD = priorRMSSD.reduce(0, +) / Double(priorRMSSD.count)
            rmssdChange = avgPriorRMSSD > 0 ? (avgRecentRMSSD - avgPriorRMSSD) / avgPriorRMSSD : 0
        }

        // Improving: HR decreased ≥5% OR RMSSD increased ≥10%
        if hrChange <= -0.05 || rmssdChange >= 0.10 {
            return .improving
        }

        // Declining: HR increased ≥10% OR RMSSD decreased ≥15%
        if hrChange >= 0.10 || rmssdChange <= -0.15 {
            return .declining
        }

        return .stable
    }

    /// Groups sorted samples into sessions using a 2-minute gap threshold
    static func groupIntoSessions(_ sortedSamples: [PhysiologicalSample]) -> [[PhysiologicalSample]] {
        guard !sortedSamples.isEmpty else { return [] }

        var sessions: [[PhysiologicalSample]] = []
        var currentSession: [PhysiologicalSample] = [sortedSamples[0]]

        for i in 1..<sortedSamples.count {
            let gap = sortedSamples[i].windowStart.timeIntervalSince(sortedSamples[i - 1].windowStart)
            if gap <= 120 { // 2 minutes
                currentSession.append(sortedSamples[i])
            } else {
                sessions.append(currentSession)
                currentSession = [sortedSamples[i]]
            }
        }
        sessions.append(currentSession)

        return sessions
    }

    /// Builds a 7-day overview from samples
    static func buildOverview(from samples: [PhysiologicalSample]) -> PatientOverview {
        let avgHR = samples.map(\.avgHeartRate).reduce(0, +) / Double(samples.count)

        let rmssdValues = samples.compactMap(\.rmssd)
        let avgRMSSD: Double? = rmssdValues.isEmpty ? nil : rmssdValues.reduce(0, +) / Double(rmssdValues.count)

        let sdnnValues = samples.compactMap(\.sdnn)
        let avgSDNN: Double? = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)

        let sessions = groupIntoSessions(samples)
        let totalMinutes = samples.count

        // Daily aggregates for charts
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: samples) { sample in
            calendar.startOfDay(for: sample.windowStart)
        }

        let dailyHR: [(date: Date, value: Double)] = grouped.map { (date, daySamples) in
            let avg = daySamples.map(\.avgHeartRate).reduce(0, +) / Double(daySamples.count)
            return (date: date, value: avg)
        }.sorted { $0.date < $1.date }

        let dailyRMSSD: [(date: Date, value: Double)] = grouped.compactMap { (date, daySamples) in
            let vals = daySamples.compactMap(\.rmssd)
            guard !vals.isEmpty else { return nil }
            let avg = vals.reduce(0, +) / Double(vals.count)
            return (date: date, value: avg)
        }.sorted { $0.date < $1.date }

        return PatientOverview(
            avgHeartRate7d: avgHR,
            avgRMSSD7d: avgRMSSD,
            avgSDNN7d: avgSDNN,
            sessionCount7d: sessions.count,
            totalMinutes7d: totalMinutes,
            dailyHeartRates: dailyHR,
            dailyRMSSD: dailyRMSSD
        )
    }

    /// Computes dashboard stats from in-memory data (pure function, testable without Supabase)
    static func computeDashboardStats(
        relationships: [ClinicianPatient],
        samples: [PhysiologicalSample],
        invitationCodes: [InvitationCode],
        now: Date = Date()
    ) -> DashboardStats {
        // Active patients: status == .activo AND endDate == nil
        let activePatientIds = Set(
            relationships
                .filter { $0.status == .activo && $0.endDate == nil }
                .map { $0.patientId }
        )
        let totalActive = activePatientIds.count

        // Patients active today: distinct patient IDs with a sample in the last 24h
        let twentyFourHoursAgo = Calendar.current.date(byAdding: .hour, value: -24, to: now)!
        let patientsActiveToday = Set(
            samples
                .filter { activePatientIds.contains($0.userId) && $0.windowStart >= twentyFourHoursAgo }
                .map { $0.userId }
        ).count

        // Pending invitations
        let pendingInvitations = invitationCodes.filter { $0.status == .pending }.count

        return DashboardStats(
            totalActivePatients: totalActive,
            patientsActiveToday: patientsActiveToday,
            pendingInvitations: pendingInvitations
        )
    }

    /// Classifies needs-attention items from in-memory data (pure function, testable without Supabase)
    static func classifyNeedsAttention(
        patientIds: [UUID],
        profiles: [UUID: UserProfile],
        samplesByPatient: [UUID: [PhysiologicalSample]],
        now: Date = Date()
    ) -> [NeedsAttentionItem] {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let fourteenDaysAgo = Calendar.current.date(byAdding: .day, value: -14, to: now)!
        var items: [NeedsAttentionItem] = []

        for patientId in patientIds {
            guard let profile = profiles[patientId] else { continue }
            let patientName = profile.name ?? "Unknown"
            let patientSamples = samplesByPatient[patientId] ?? []
            let recent7d = patientSamples.filter { $0.windowStart >= sevenDaysAgo && $0.windowStart <= now }
            let prior7d = patientSamples.filter { $0.windowStart >= fourteenDaysAgo && $0.windowStart < sevenDaysAgo }

            // Inactivity: no samples in last 7 days
            if recent7d.isEmpty {
                let lastSample = patientSamples.filter { $0.windowStart <= now }.max(by: { $0.windowStart < $1.windowStart })
                let daysSince: Int
                if let last = lastSample {
                    daysSince = Calendar.current.dateComponents([.day], from: last.windowStart, to: now).day ?? 7
                } else {
                    daysSince = 7
                }
                items.append(NeedsAttentionItem(
                    id: patientId,
                    patientName: patientName,
                    reason: .inactivity,
                    detail: "\(daysSince) days since last session"
                ))
            }

            // Elevated HR: 7d avg exceeds baseline by ≥15%
            if !recent7d.isEmpty, let baseline = profile.restingHeartRate, baseline > 0 {
                let avgHR = recent7d.map(\.avgHeartRate).reduce(0, +) / Double(recent7d.count)
                let percentIncrease = (avgHR - baseline) / baseline * 100
                if percentIncrease >= 15 {
                    items.append(NeedsAttentionItem(
                        id: patientId,
                        patientName: patientName,
                        reason: .elevatedHeartRate,
                        detail: String(format: "HR +%.0f%% above baseline", percentIncrease)
                    ))
                }
            }

            // Declining HRV: 7d avg RMSSD declined ≥25% vs prior 7d
            let recentRMSSD = recent7d.compactMap(\.rmssd)
            let priorRMSSD = prior7d.compactMap(\.rmssd)
            if !recentRMSSD.isEmpty, !priorRMSSD.isEmpty {
                let avgRecent = recentRMSSD.reduce(0, +) / Double(recentRMSSD.count)
                let avgPrior = priorRMSSD.reduce(0, +) / Double(priorRMSSD.count)
                if avgPrior > 0 {
                    let decline = (avgPrior - avgRecent) / avgPrior * 100
                    if decline >= 25 {
                        items.append(NeedsAttentionItem(
                            id: patientId,
                            patientName: patientName,
                            reason: .decliningHRV,
                            detail: String(format: "RMSSD declined %.0f%%", decline)
                        ))
                    }
                }
            }
        }

        return items
    }

    /// Selects the most recent activity items from sessions (pure function, testable without Supabase)
    static func selectRecentActivity(_ items: [RecentActivityItem], limit: Int) -> [RecentActivityItem] {
        Array(items.sorted { $0.sessionDate > $1.sessionDate }.prefix(limit))
    }

    /// Filters relationships to only active ones (pure function, testable without Supabase)
    static func activePatientIds(from relationships: [ClinicianPatient]) -> [UUID] {
        relationships
            .filter { $0.status == .activo && $0.endDate == nil }
            .map { $0.patientId }
    }

    /// Computes sample aggregates (pure function, testable without Supabase)
    static func computeAggregates(from samples: [PhysiologicalSample]) -> (avgHR: Double, avgRMSSD: Double?, avgSDNN: Double?, totalMinutes: Int) {
        guard !samples.isEmpty else { return (0, nil, nil, 0) }

        let avgHR = samples.map(\.avgHeartRate).reduce(0, +) / Double(samples.count)

        let rmssdValues = samples.compactMap(\.rmssd)
        let avgRMSSD: Double? = rmssdValues.isEmpty ? nil : rmssdValues.reduce(0, +) / Double(rmssdValues.count)

        let sdnnValues = samples.compactMap(\.sdnn)
        let avgSDNN: Double? = sdnnValues.isEmpty ? nil : sdnnValues.reduce(0, +) / Double(sdnnValues.count)

        return (avgHR, avgRMSSD, avgSDNN, samples.count)
    }

    /// Generates a random alphanumeric code of the given length
    static func generateRandomCode(length: Int) -> String {
        let characters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }
}
