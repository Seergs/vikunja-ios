# Architecture

This is the design doc behind this project's structure. It predates most of the
code and is kept here as a reference for *why* things are laid out the way they
are, not just *what* is where — see `CLAUDE.md` for the current, code-derived
summary.

## Context

This app is a native iOS client (Swift/SwiftUI) for [Vikunja](https://vikunja.io),
the open-source task manager people commonly self-host. Since every user points
the app at their own instance (their own URL, their own backend version, their own
configuration), the app needs:

1. A clear module/folder structure under **MVVM**.
2. A network abstraction layer so that a change in Vikunja's API doesn't force
   changes to views/view models — only to the networking layer.
3. A way to coexist with instances on different backend versions, each with its
   own set of enabled/disabled features.

Decisions locked in from the start: **SwiftUI only**, **Swift Package Manager,
multi-module**, **no local persistence for now** (everything is re-fetched from the
server; offline support is a later phase).

**Implementation status**: `VikunjaCore`, `VikunjaNetworking`, `VikunjaAuth`,
`VikunjaNavigation`, `VikunjaDesignSystem` (starter token set — see below),
`Features/Onboarding`, the `AppContainer` composition root, and the top-level
navigation shell (onboarding → floating tab bar, one `NavigationStack` per tab)
are built (see `Packages/` and `vikunja/`). `Features/Projects` is built end to
end: a collapsible parent/child project tree, a project overview (subprojects +
tasks grouped by status), and it pushes into `Features/Tasks`'s task detail
screen (completion, due date, priority, labels, subtasks, dependencies) — also
built, as a leaf screen with no navigation stack of its own. `Features/Settings`
has one real action (reset the saved connection); `Features/Home` and
`Features/Search` are still placeholder screens.

---

## 1. Module structure (Swift Package Manager)

A thin Xcode project (just the app shell / composition root) plus several local
Swift Packages. Layer boundaries are enforced by the compiler, not by discipline —
if `Features/Tasks` tries to import `VikunjaNetworking` directly, it won't build.

```
vikunja-ios/
├── vikunja.xcodeproj          # shell: app entry point + composition root
├── vikunja/
│   ├── vikunjaApp.swift       # @main, builds the AppContainer and injects it
│   ├── AppContainer.swift     # composition root: builds concrete implementations
│   │                           # and injects them as protocols into each feature
│   ├── RootView.swift         # onboarding vs. main tab bar
│   └── Navigation/
│       ├── AppTab.swift               # the tab enum (iOS-26-only Tab APIs live here,
│       ├── MainTabView.swift          # not in a package, since packages floor at iOS 17)
│       └── QuickAddAccessoryView.swift
│
└── Packages/
    ├── VikunjaCore/               # 100% pure Swift, no networking, no UI
    │   └── Sources/VikunjaCore/
    │       ├── Domain/            # domain models (Task, Project, User, Label,
    │       │                      # TaskRelation, InstanceAccount, InstanceURL...)
    │       ├── Protocols/         # TaskRepositoryProtocol, AuthServiceProtocol,
    │       │                      # AccountStoreProtocol, InstanceClientFactoryProtocol
    │       ├── Capabilities/      # VikunjaServerInfo, CapabilityProvider
    │       └── Errors/            # VikunjaError (domain-level, not HTTP)
    │
    ├── VikunjaNetworking/         # the ONLY place that knows a REST API exists
    │   └── Sources/VikunjaNetworking/
    │       ├── Client/            # APIClient protocol + URLSessionAPIClient
    │       ├── Endpoints/         # per-resource endpoint definitions
    │       ├── DTOs/              # Codable models mirroring the server's JSON
    │       ├── Mappers/           # DTO -> domain model (VikunjaCore)
    │       └── Repositories/      # implement VikunjaCore's protocols
    │                              # (incl. VikunjaInstanceClientFactory)
    │
    ├── VikunjaAuth/               # multi-account/instance + Keychain
    │   └── Sources/VikunjaAuth/
    │       ├── KeychainAccountStore.swift   # implements Core's AccountStoreProtocol
    │       └── Keychain.swift               # internal Keychain Services wrapper
    │
    ├── VikunjaNavigation/         # pure SwiftUI/Observation, no networking, no deps
    │   └── Sources/VikunjaNavigation/
    │       └── Router.swift       # generic Router<Route: Hashable>, wraps NavigationPath
    │
    ├── VikunjaDesignSystem/       # colors, typography, spacing tokens; toast system (growing set)
    │   └── Sources/VikunjaDesignSystem/
    │       └── Toast/             # ToastCenter (implements Core's ToastPresenting), ToastView, toastHost(_:)
    │
    └── Features/
        ├── Onboarding/            # "connect to your instance" — built end to end
        ├── Home/                  # landing tab — placeholder content, real navigation shell
        ├── Projects/              # projects tab — built end to end (list, tree, overview)
        ├── Search/                # search tab (iOS 26 `.search` role) — placeholder
        ├── Settings/              # settings tab — placeholder content + reset-connection action
        ├── Tasks/                 # task detail screen — built, pushed by Projects as a leaf
        └── ...
```

### Dependency rules

This is what protects the app when Vikunja's API changes:

- `VikunjaCore` → depends on nothing.
- `VikunjaNavigation` → depends on nothing (pure SwiftUI/Observation).
- `VikunjaNetworking` and `VikunjaAuth` → depend on `VikunjaCore` (they implement
  its protocols), but **nothing else depends on them except the composition root**.
- `VikunjaDesignSystem` → depends on `VikunjaCore` too, for the same reason:
  `ToastCenter` implements Core's `ToastPresenting` protocol, so a ViewModel can
  take a toast dependency via constructor injection without importing
  `VikunjaDesignSystem` or SwiftUI. Every other token in the package stays
  dependency-free.
- `Features/*` → depend on `VikunjaCore` (protocols + models), `VikunjaNavigation`,
  and `VikunjaDesignSystem`. They **never** import `VikunjaNetworking` directly.
  Views use `VikunjaDesignSystem` tokens (`VikunjaColor`, `VikunjaFont`,
  `VikunjaSpacing`) instead of hardcoding colors, fonts, or spacing values —
  that's what keeps the app visually consistent as `VikunjaDesignSystem` grows.
- The app / composition root → the only place that knows both `VikunjaCore`'s
  protocols and `VikunjaNetworking`/`VikunjaAuth`'s concrete implementations, and
  wires them together. It's also the only place that knows about every Feature's
  root view at once (to build the tab bar) — Features never reference each other.

If Vikunja changes its API tomorrow (renames a field, changes an endpoint, adds a
resource), the change stays contained to `VikunjaNetworking`. Features and their
view models never notice, because they only know about protocols and domain
models.

---

## 2. MVVM per feature

Each `Features/<Name>` folder follows the same internal shape:

```
Features/Tasks/Sources/Tasks/
├── Models/            # (view-specific state, if needed — not domain models)
├── ViewModels/
│   └── TaskListViewModel.swift
├── Views/
│   ├── TasksRootView.swift   # public: owns the NavigationStack + Router
│   ├── TaskListView.swift    # internal: content, no navigation knowledge
│   └── TaskRowView.swift
└── Navigation/
    └── TasksRoute.swift      # private route enum
```

- **Model**: comes from `VikunjaCore.Domain` (e.g. `Task`, `Project`). No network
  models here — those are DTOs and stay locked inside `VikunjaNetworking`.
- **ViewModel**: `@Observable` (or `ObservableObject` if the iOS minimum requires
  it), receives a protocol via **constructor injection**, never a concrete
  networking class:

  ```swift
  // VikunjaCore/Protocols/TaskRepositoryProtocol.swift
  public protocol TaskRepositoryProtocol {
      func fetchTasks(projectID: Project.ID) async throws -> [VikunjaTask]
      func update(_ task: VikunjaTask) async throws -> VikunjaTask
  }

  // Features/Tasks/ViewModels/TaskListViewModel.swift
  @Observable
  final class TaskListViewModel {
      private let repository: TaskRepositoryProtocol
      init(repository: TaskRepositoryProtocol) { self.repository = repository }
      ...
  }
  ```

- **View**: pure SwiftUI, only reads state from the ViewModel and sends it
  intents. Zero business logic, zero networking knowledge.
- **Navigation**: `VikunjaNavigation.Router<Route>` — a generic
  `@Observable`/`@MainActor` wrapper around `NavigationPath`
  (`push`/`pop`/`popToRoot`) — typed to a private `Route` enum per feature. The
  feature's only public view, `<Name>RootView`, owns one `@State` `Router`
  instance, wraps its content in `NavigationStack(path: router.path)`, and
  declares `.navigationDestination(for: Route.self)`. Nothing outside the
  package ever sees the route enum or touches `NavigationPath` directly — this
  keeps Views from coupling to each other via direct
  `NavigationLink(destination:)`, and keeps each tab's navigation state
  independent of the others (see §2b).

This keeps "V" and "VM" cleanly separated from "M", and the Model never knows HTTP
exists — only `VikunjaNetworking` does.

**Exception — a feature with no top-level screen of its own**: `Features/Tasks`
as actually built is a single task-detail screen, always pushed as a leaf onto
whichever feature's stack opened it (`Features/Projects`, today) — never
reachable from the tab bar directly. It skips `Navigation/`/`Router` entirely
and exposes a plain public view; the feature that pushes it takes a
type-erased `(VikunjaTask, Project) -> AnyView` closure (built by
`AppContainer`) instead of importing it, so the pushing feature still never
imports another Feature's package.

---

## 2b. Top-level navigation: onboarding → floating tab bar

`vikunja/RootView.swift` is the only place that switches between the two
top-level app states: no connected account (`InstanceSetupView`, from
`Features/Onboarding`) and a connected account (`MainTabView`). It holds this as
plain `@State private var connectedAccount: InstanceAccount?` — two states don't
need a dedicated enum.

`MainTabView` (`vikunja/Navigation/MainTabView.swift`) is the floating, Liquid
Glass bottom tab bar — the default rendering for `TabView` built with the modern
`Tab(value:)` API on iOS 26+, no extra styling code required. One `Tab` per
`AppTab` case, each hosting a different Feature's `<Name>RootView`, so every tab
keeps its own independent `NavigationStack`/`Router` — switching tabs never
resets where you were in another one (the same pattern Apple's own Music/App
Store apps use):

```swift
TabView(selection: $selection) {
    Tab(AppTab.home.title, systemImage: AppTab.home.systemImage, value: .home) {
        HomeRootView(accountName: account.displayName)
    }
    Tab(AppTab.projects.title, systemImage: AppTab.projects.systemImage, value: .projects) {
        ProjectsRootView()
    }
    Tab(AppTab.settings.title, systemImage: AppTab.settings.systemImage, value: .settings) {
        SettingsRootView()
    }
    Tab(value: AppTab.search, role: .search) {   // separated glass pill, iOS 26 search role
        SearchRootView()
    }
}
.tabViewBottomAccessory {                         // floating accessory above the bar
    QuickAddAccessoryView()                        // placeholder — no task-creation flow yet
}
.tabBarMinimizeBehavior(.onScrollDown)
```

`AppTab`, `MainTabView`, and `QuickAddAccessoryView` live in the app target, not a
package, because `Tab(role:)`, `.tabViewBottomAccessory`, and
`.tabBarMinimizeBehavior` are iOS-26-only APIs, while every package floors at
`.iOS(.v17)` for portability (see `CLAUDE.md` § Conventions). `AppTab` is also the
one enum allowed to know about every Feature's tab at once — Features themselves
never reference each other.

No root-level account switcher exists (or is planned) outside Settings — with
only API-token auth and no multi-instance UI built yet, switching accounts stays
a `Features/Settings` concern rather than top-level navigation state.

---

## 3. Network abstraction layer (protection against API changes)

Three layers, each with a single responsibility:

**a) `APIClient` — generic transport, knows nothing about Vikunja**

```swift
public protocol APIClient {
    func send<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func send(_ endpoint: Endpoint) async throws // no response body
}
```

The concrete implementation (`URLSessionAPIClient`) resolves the active instance's
base URL, attaches auth headers, handles token refresh, and maps raw HTTP errors to
domain-level `VikunjaError`. An `Endpoint` is a plain struct (path, method, query,
body) — adding/changing an endpoint means touching a single file.

**b) DTOs + Mappers — the buffer against JSON changes**

DTOs (`TaskDTO`, `ProjectDTO`, ...) are a *tolerant* mirror of the real JSON
(optional fields where the server added them recently, explicit `CodingKeys`). A
`Mapper` converts a DTO into a `VikunjaCore` domain model. If Vikunja renames or
adds a field, you touch the DTO and the mapper; the domain model and everything
upstream (ViewModels, Views) stays untouched.

**c) `Repository` — implements `VikunjaCore`'s protocols**

```swift
final class VikunjaTaskRepository: TaskRepositoryProtocol {
    private let client: APIClient
    func fetchTasks(projectID: Project.ID) async throws -> [VikunjaTask] {
        let dtos: [TaskDTO] = try await client.send(.tasks(projectID: projectID))
        return dtos.map(TaskMapper.toDomain)
    }
}
```

This is the piece injected into the `AppContainer` and handed to Features **as a
protocol**. If the API changes, worst case you rewrite `APIClient`, `Endpoint`s,
DTOs, and `Mapper`s — zero changes in `VikunjaCore` or `Features`.

---

## 4. Different instances, different server versions

Solved with **runtime feature detection**, not hand-rolled `if version > X` checks
scattered everywhere. Vikunja exposes a public `GET /api/v1/info` endpoint that
returns the server version and flags like `caldav_enabled`, `totp_enabled`,
`max_file_size`, registration limits, etc. — this maps directly onto the design:

```swift
// VikunjaCore/Capabilities/VikunjaServerInfo.swift
public struct VikunjaServerInfo: Sendable {
    public let version: String
    public let caldavEnabled: Bool
    public let totpEnabled: Bool
    public let registrationEnabled: Bool
    // ... remaining flags exposed by /info
}

public protocol CapabilityProvider {
    var serverInfo: VikunjaServerInfo { get async throws }
    func supports(_ feature: VikunjaFeature) -> Bool
}
```

- When connecting to an instance (or logging in), the app hits `/info` once,
  stores the result in the `SessionManager` for that account, and caches it in
  memory.
- Features query `capabilityProvider.supports(.totp)` to show/hide UI, instead of
  hardcoding version comparisons spread across the codebase.
- For differences in **JSON shape** between old/new backend versions (not just
  feature on/off flags), the buffer is the tolerant DTOs from section 3b: optional
  fields plus defaults, and if needed, a mapper that branches by version
  (`if serverInfo.version < "0.24" { ... }`) — but that logic stays **locked inside
  `VikunjaNetworking`**, never leaking into a Feature.
- If Vikunja ever ships a truly incompatible change (a new API shape, not just new
  fields), the pattern scales by adding a second `Mapper` (`TaskMapperV2`) selected
  at runtime based on `serverInfo.version` — still without touching anything
  outside `VikunjaNetworking`.

---

## 5. Multi-account / multi-instance (Mastodon-app style)

Each user can have 1+ configured instances (their own self-hosted one, a work
instance, the public Vikunja instance, etc). `InstanceAccount` and
`AccountStoreProtocol` live in `VikunjaCore` — not `VikunjaAuth` as originally
sketched here — because `AccountStoreProtocol` needs to reference
`InstanceAccount` in its signature, and `VikunjaCore` depends on nothing:

```swift
public struct InstanceAccount: Identifiable, Codable {
    public let id: UUID
    public var displayName: String
    public var baseURL: URL
    public var createdAt: Date
    // the token itself does NOT live here — it's in the Keychain, referenced by `id`
}
```

- Only API token auth is modeled for now (`AuthServiceProtocol.loginWithAPIToken`,
  not the password/JWT flow) — no `authMethod` field on `InstanceAccount` until a
  second auth method actually needs one.
- `AccountStoreProtocol` (`VikunjaCore`) is implemented by `KeychainAccountStore`
  in `VikunjaAuth`: it stores the account list, each account's bearer token
  (keyed by account id, so removing one account never touches another's secret),
  and which account is active — all in the Keychain, never `UserDefaults`.
  Adding an account makes it the active one.
- `InstanceClientFactoryProtocol` (`VikunjaCore`, implemented by
  `VikunjaInstanceClientFactory` in `VikunjaNetworking`) builds a
  `CapabilityProvider` for a URL that doesn't have an account yet — this is what
  lets the onboarding flow probe `GET /api/v1/info` to confirm an address is a
  real Vikunja instance before the connection is saved.
- `InstanceURL.normalize(_:)` (`VikunjaCore`) turns whatever the user typed — a
  bare domain or a full URL, with or without a trailing path — into the
  scheme+host `URL` the networking layer expects as `baseURL`.
- A `SessionManager` that tracks the active account's live `APIClient` +
  `CapabilityProvider` for the rest of the app to use, and OIDC support, are
  still future work — not needed yet, since nothing outside onboarding consumes
  an active connection today.

---

## 6. Dependency Injection

No third-party library: a plain `AppContainer` in the `App` target, using
constructor injection. It's the only file in the project that imports both
`Core`'s protocols and `Networking`/`Auth`'s concrete implementations.

```swift
@MainActor
final class AppContainer {
    let sessionManager: SessionManager
    let taskRepository: TaskRepositoryProtocol
    let capabilityProvider: CapabilityProvider
    // ...

    init() {
        let session = KeychainSessionManager()
        self.sessionManager = session
        self.taskRepository = VikunjaTaskRepository(client: session.apiClient)
        self.capabilityProvider = VikunjaCapabilityProvider(client: session.apiClient)
    }
}
```

This keeps zero new external dependencies, stays testable (tests build an
`AppContainer` with mocks conforming to the same protocols), and reinforces the
central idea: anything "dirty" about networking lives behind a wall of protocols.

---

## 7. Testing

- `VikunjaCore` has no networking → trivial to test in isolation.
- `VikunjaNetworking` is tested with **real JSON fixtures** captured from Vikunja
  instances on different versions (contract tests) — this is what gives an early
  warning if a new server version broke a DTO.
- `VikunjaNavigation`'s `Router` is tested directly (push/pop/popToRoot against a
  private test route enum), independent of any Feature that uses it.
- `Features/*` test their ViewModels against fake implementations of `Core`'s
  protocols (no need to spin up networking or mock HTTP).

---

## Next steps

The shell is built and wired, and the most central slice of Vikunja's model is
now real: `Projects` (list → tree → overview) and `Tasks` (detail, reachable
from a project's task list) both sit on top of `VikunjaCore`/`VikunjaNetworking`
end to end, including relations (subtasks/dependencies). What's still a
placeholder is `Home` (just confirms the connected instance) and `Search`
(bare screen) — the natural next slice is giving `Search` a real query against
`ProjectRepositoryProtocol`/`TaskRepositoryProtocol`, since both already exist.
`Settings` has only one real action (reset connection) — an account switcher
and preferences are still open. The quick-add accessory's `onTap` is the other
open thread — today it's a visible no-op; wiring it up will likely mean giving
`Tasks` a create flow, not just the read-only detail screen it has now.
