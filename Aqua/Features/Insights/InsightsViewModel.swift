import Combine
import Foundation

enum InsightsViewState: Equatable {
    case loading
    case empty(HydrationInsightsReport)
    case loaded(HydrationInsightsReport)
    case failed(message: String)

    var report: HydrationInsightsReport? {
        switch self {
        case .empty(let report), .loaded(let report): report
        case .loading, .failed: nil
        }
    }
}

@MainActor
final class InsightsViewModel: ObservableObject {
    @Published private(set) var state: InsightsViewState = .loading
    @Published private(set) var isRefreshing = false

    private let service: any HydrationInsightsProviding
    private let dateProvider: any DateProviding
    private var refreshTask: Task<Void, Never>?
    private var activeRequestID: UUID?

    init(
        service: any HydrationInsightsProviding,
        dateProvider: any DateProviding
    ) {
        self.service = service
        self.dateProvider = dateProvider
    }

    func loadIfNeeded() async {
        guard state.report == nil else { return }
        await refresh(displaysLoading: true)
    }

    func requestRefresh(
        displaysLoading: Bool = false,
        debounce: Bool = false
    ) {
        let previousTask = refreshTask
        previousTask?.cancel()
        let requestID = UUID()
        activeRequestID = requestID
        if displaysLoading { state = .loading }

        let task = Task { [weak self] in
            await previousTask?.value
            if debounce {
                do {
                    try await Task.sleep(for: .milliseconds(250))
                } catch {
                    return
                }
            }
            guard !Task.isCancelled else { return }
            await self?.performLoad(requestID: requestID)
        }
        refreshTask = task
    }

    func refresh(displaysLoading: Bool = false) async {
        requestRefresh(displaysLoading: displaysLoading)
        let task = refreshTask
        await task?.value
    }

    func cancel() {
        activeRequestID = nil
        refreshTask?.cancel()
        isRefreshing = false
    }

    private func performLoad(requestID: UUID) async {
        guard activeRequestID == requestID else { return }
        isRefreshing = true
        defer {
            if activeRequestID == requestID {
                isRefreshing = false
                activeRequestID = nil
                refreshTask = nil
            }
        }

        do {
            let report = try await service.insights(asOf: dateProvider.now)
            guard activeRequestID == requestID, !Task.isCancelled else { return }
            state = report.snapshot.hasSufficientHistory && !report.insights.isEmpty
                ? .loaded(report)
                : .empty(report)
        } catch is CancellationError {
            return
        } catch {
            guard activeRequestID == requestID, !Task.isCancelled else { return }
            state = .failed(message: error.localizedDescription)
        }
    }
}
