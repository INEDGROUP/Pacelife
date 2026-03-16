import Foundation
import HealthKit
import SwiftUI

@MainActor
class HealthKitService: ObservableObject {
    static let shared = HealthKitService()
    private let store = HKHealthStore()

    @Published var isAuthorized = false
    @Published var todaySteps: Int = 0
    @Published var lastNightSleep: Double = 0
    @Published var todayActiveEnergy: Double = 0

    private init() {
        Task { await initialFetch() }
    }

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    private var readTypes: Set<HKObjectType> {
        var types = Set<HKObjectType>()
        if let v = HKObjectType.quantityType(forIdentifier: .stepCount) { types.insert(v) }
        if let v = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) { types.insert(v) }
        if let v = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) { types.insert(v) }
        if let v = HKObjectType.quantityType(forIdentifier: .heartRate) { types.insert(v) }
        return types
    }

    func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            await fetchAllData()
            isAuthorized = true
            return true
        } catch {
            return false
        }
    }

    func checkAuthorization() async {
        await fetchAllData()
    }

    func initialFetch() async {
        guard isAvailable else { return }
        await fetchAllData()
    }

    func fetchAllData() async {
        await fetchTodaySteps()
        await fetchLastNightSleep()
        await fetchActiveEnergy()
    }

    func fetchTodaySteps() async {
        guard isAvailable else { return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)

        let steps = await withCheckedContinuation { (continuation: CheckedContinuation<Int, Never>) in
            var totalSteps = 0.0
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: [])
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, error in
                if let error = error {
                    continuation.resume(returning: 0)
                    return
                }
                guard let samples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: 0)
                    return
                }
                for sample in samples {
                    totalSteps += sample.quantity.doubleValue(for: HKUnit.count())
                }
                continuation.resume(returning: Int(totalSteps))
            }
            self.store.execute(query)
        }

        todaySteps = steps
        if steps > 0 { isAuthorized = true }
    }

    func fetchLastNightSleep() async {
        guard isAvailable else { return }
        guard let type = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) else { return }

        let now = Date()
        let yesterday = Calendar.current.date(byAdding: .hour, value: -18, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: yesterday, end: now, options: [])
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)

        let samples = await withCheckedContinuation { (continuation: CheckedContinuation<[HKCategorySample], Never>) in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: 50,
                sortDescriptors: [sortDescriptor]
            ) { _, results, error in
                if let error = error {
                    continuation.resume(returning: [])
                    return
                }
                let sleepSamples = results as? [HKCategorySample] ?? []
                continuation.resume(returning: sleepSamples)
            }
            self.store.execute(query)
        }

        let asleepSamples = samples.filter {
            $0.value == HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
            $0.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue
        }

        let totalSeconds = asleepSamples.reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        let hours = min(totalSeconds / 3600, 12.0)
        lastNightSleep = hours
    }

    func fetchActiveEnergy() async {
        guard isAvailable else { return }
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

        let now = Date()
        let startOfDay = Calendar.current.startOfDay(for: now)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now, options: [])

        let energy = await withCheckedContinuation { (continuation: CheckedContinuation<Double, Never>) in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                let value = result?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
                continuation.resume(returning: value)
            }
            self.store.execute(query)
        }
        todayActiveEnergy = energy
    }

    var stepProgress: Double { min(Double(todaySteps) / 10000.0, 1.0) }

    var stepStatusText: String {
        switch todaySteps {
        case 0: return "No steps yet"
        case 1..<3000: return "Just getting started"
        case 3000..<7000: return "Good progress"
        case 7000..<10000: return "Almost there"
        default: return "Goal reached!"
        }
    }

    var sleepQualityText: String {
        switch lastNightSleep {
        case 0..<1: return "Not tracked"
        case 1..<5: return "Poor"
        case 5..<6: return "Fair"
        case 6..<7: return "Okay"
        case 7..<8: return "Good"
        case 8..<9: return "Great"
        default: return "Excellent"
        }
    }

    var sleepQualityColor: Color {
        switch lastNightSleep {
        case 0..<5: return .plRed
        case 5..<7: return .plAmber
        default: return .plGreen
        }
    }
}
