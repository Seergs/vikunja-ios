/// The semantic category of a toast. Purely descriptive — icon, color, and
/// display duration are a rendering concern owned by whatever implements
/// `ToastPresenting`, not this type.
public enum ToastStyle: Sendable, Equatable {
    case success
    case error
    case info
}
