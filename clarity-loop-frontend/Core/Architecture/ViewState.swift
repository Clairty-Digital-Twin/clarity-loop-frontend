import Foundation

/// A generic enum to represent the state of a view that loads data asynchronously.
/// This provides a consistent way to handle loading, error, and content states across different features.
enum ViewState<T: Equatable>: Equatable {
    /// The view is idle and has not yet started loading.
    case idle

    /// The view is currently loading data.
    case loading

    /// The view has successfully loaded the data.
    case loaded(T)
    
    /// The view loaded successfully, but there is no data to display.
    case empty

    /// The view encountered an error while loading data.
    case error(Error)
    
    // MARK: - Computed Properties
    
    /// Returns true if the view is currently loading
    var isLoading: Bool {
        if case .loading = self {
            return true
        }
        return false
    }
    
    /// Returns true if the view has loaded successfully
    var isLoaded: Bool {
        if case .loaded = self {
            return true
        }
        return false
    }
    
    /// Returns true if the view has an error
    var hasError: Bool {
        if case .error = self {
            return true
        }
        return false
    }
    
    /// Returns true if the view is empty
    var isEmpty: Bool {
        if case .empty = self {
            return true
        }
        return false
    }
    
    /// Returns the loaded value if available
    var value: T? {
        if case .loaded(let value) = self {
            return value
        }
        return nil
    }
    
    /// Returns the error if available
    var error: Error? {
        if case .error(let error) = self {
            return error
        }
        return nil
    }
    
    // MARK: - Convenience Methods
    
    /// Maps the loaded value to a new type
    func map<U: Equatable>(_ transform: (T) -> U) -> ViewState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return .loaded(transform(value))
        case .empty:
            return .empty
        case .error(let error):
            return .error(error)
        }
    }
    
    /// Maps the loaded value to a new ViewState
    func flatMap<U: Equatable>(_ transform: (T) -> ViewState<U>) -> ViewState<U> {
        switch self {
        case .idle:
            return .idle
        case .loading:
            return .loading
        case .loaded(let value):
            return transform(value)
        case .empty:
            return .empty
        case .error(let error):
            return .error(error)
        }
    }
}

// MARK: - Equatable Conformance for Error

extension ViewState {
    static func == (lhs: ViewState<T>, rhs: ViewState<T>) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.empty, .empty):
            return true
        case (.loaded(let lhsValue), .loaded(let rhsValue)):
            return lhsValue == rhsValue
        case (.error(let lhsError), .error(let rhsError)):
            // Compare error descriptions since Error isn't Equatable
            return (lhsError as NSError) == (rhsError as NSError)
        default:
            return false
        }
    }
}
