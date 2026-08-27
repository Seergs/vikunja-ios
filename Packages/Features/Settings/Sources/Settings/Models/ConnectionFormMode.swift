import VikunjaCore

/// Which of the two things `ConnectionFormViewModel`/`ConnectionFormView` is
/// doing: adding a brand-new connection, or editing an already-saved one.
/// Unlike `Onboarding`'s `InstanceSetupViewModel` (the first-run, no-accounts-
/// yet flow), both cases here assume at least one connection already exists.
public enum ConnectionFormMode: Hashable, Sendable {
    case create
    case edit(InstanceAccount)
}
