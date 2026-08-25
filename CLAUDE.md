# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Native iOS SwiftUI client for [Vikunja](https://vikunja.io), the open-source
self-hosted task manager. Each user points the app at their own Vikunja instance
(their own URL, their own server version, their own enabled features), so the
architecture is built around isolating "talking to Vikunja's API" from everything
else, and around detecting server capabilities at runtime rather than assuming one
fixed API shape.

## Commands

Fastest iteration loop is building/testing the Swift packages directly (no
simulator boot required):

```sh
cd Packages/VikunjaCore && swift build && swift test
cd Packages/VikunjaNetworking && swift build && swift test
cd Packages/VikunjaAuth && swift build && swift test
cd Packages/VikunjaNavigation && swift build && swift test
cd Packages/VikunjaDesignSystem && swift build && swift test
cd Packages/Features/Onboarding && swift build && swift test
cd Packages/Features/Projects && swift build && swift test
cd Packages/Features/Tasks && swift build && swift test
```

Run a single test (packages use swift-testing, not XCTest):

```sh
swift test --filter <SuiteName>          # whole suite
swift test --filter <SuiteName>/<testName>
```

Build the full app target (compiles both local packages and links them in):

```sh
xcodebuild -project vikunja.xcodeproj -scheme vikunja -destination 'generic/platform=iOS Simulator' build
```

List targets/schemes:

```sh
xcodebuild -list -project vikunja.xcodeproj
```

## Architecture

Full design rationale (including the parts not built yet — see `ARCHITECTURE.md`'s
own "Next steps") lives in `ARCHITECTURE.md`. This section is the current,
code-derived summary.

MVVM with protocol-oriented layering, split across local Swift Packages under
`Packages/` and linked into the `vikunja` Xcode app target as local package
dependencies (added via `XCLocalSwiftPackageReference` in `project.pbxproj`, the
same thing Xcode's "Add Local Package" does). The dependency direction is enforced
by the compiler, not just convention:

- **`VikunjaCore`** — pure Swift, no networking, no UI, no dependencies.
  - `Domain/` — domain models (`VikunjaTask`, `Project`, `User`, `Label`,
    `TaskRelation`, `InstanceAccount`, `InstanceURL`). `InstanceAccount` holds only
    id/displayName/baseURL/createdAt — no `authMethod` field, since only API
    token auth is modeled today. `InstanceURL.normalize(_:)` turns a bare
    domain or full URL the user typed into the scheme+host `URL` the
    networking layer expects as `baseURL`. `TaskRelation` is a thin
    id/title/isDone/projectID summary (not a full recursive `VikunjaTask`) used
    for `VikunjaTask.subtasks`, `.dependsOn`, and `.blocks` — Vikunja represents
    all three the same way, as a "related task" keyed by relation kind.
  - `Protocols/` — the contracts Features are meant to depend on
    (`TaskRepositoryProtocol`, `ProjectRepositoryProtocol`, `AuthServiceProtocol`,
    `AccountStoreProtocol`, `InstanceClientFactoryProtocol`).
  - `Capabilities/` — `VikunjaServerInfo`, `CapabilityProvider`, `VikunjaFeature`:
    the runtime feature-detection layer (see below).
  - `Errors/` — `VikunjaError`, the domain-level error type everything surfaces.

- **`VikunjaNetworking`** — the only module that knows Vikunja speaks HTTP/JSON.
  Depends on `VikunjaCore`.
  - `Client/` — generic transport: `APIClient` protocol, `Endpoint` struct, and the
    concrete `URLSessionAPIClient` actor (maps HTTP status codes to `VikunjaError`).
  - `Endpoints/VikunjaEndpoints.swift` — the single file that knows Vikunja's actual
    REST routes (`/api/v1/...`). This is where a real API change gets fixed.
  - `DTOs/` — `Codable` structs mirroring the raw JSON, tolerant of optional/missing
    fields. Field names are best-effort and **must be verified against a live
    instance's swagger docs (`/api/v1/docs`)** before pointing this at a real server.
    `RelatedTaskDTO` mirrors one entry of `TaskDTO.relatedTasks` (JSON key
    `related_tasks`), a `[String: [RelatedTaskDTO]]` keyed by relation kind
    (`"subtask"`, `"blocked"`, `"blocking"`, ...).
  - `Mappers/` — DTO → domain model translation. `TaskRelationMapper` maps one
    `RelatedTaskDTO` to a `TaskRelation`; `TaskMapper` reads `subtasks`/
    `dependsOn`/`blocks` out of `TaskDTO.relatedTasks` by kind. Vikunja manages
    relations through their own endpoint rather than the task update body, so
    `TaskMapper`'s update-response mapping doesn't carry them back — see
    `TaskDetailViewModel.toggleDone()` in `Features/Tasks` for how callers
    preserve the previously-loaded relations across an update instead of
    losing them.
  - `Repositories/` — concrete implementations of `VikunjaCore`'s protocols
    (`VikunjaTaskRepository`, `VikunjaProjectRepository`, `VikunjaCapabilityProvider`,
    `VikunjaAuthService`, `VikunjaInstanceClientFactory`). These are what eventually
    get injected into Features.

- **`VikunjaAuth`** — multi-account/instance storage. Depends on `VikunjaCore`.
  - `KeychainAccountStore` — implements `AccountStoreProtocol`: the account list,
    each account's bearer token (keyed by account id, in its own Keychain item so
    removing one account never touches another's secret), and the active-account
    pointer, all in the Keychain, never `UserDefaults`. Adding an account makes it
    the active one.
  - `Keychain` — internal `Security`-framework wrapper (generic password items);
    not part of the module's public API.

- **`VikunjaNavigation`** — pure SwiftUI/Observation, no networking, no
  dependencies. The shared navigation primitive every Feature's `Navigation/`
  folder builds on.
  - `Router<Route: Hashable>` — `@Observable`, `@MainActor`. Wraps a
    `NavigationPath` with `push(_:)`/`pop()`/`popToRoot()`. Each Feature
    instantiates its own `Router<FeatureRoute>` typed to a private route enum,
    so navigation state stays local to that feature.

- **`VikunjaDesignSystem`** — pure SwiftUI, depends only on `VikunjaCore` (for
  `ToastStyle`/`ToastPresenting` — see `ToastCenter` below; every other token
  is dependency-free). The shared design tokens and views every Feature should
  build on (colors, typography, spacing; more token categories and shared
  views land here over time).
  - `VikunjaColor` — `brandPrimary` plus `VikunjaColor.Priority` (`urgent`/`high`/
    `medium`/`low`). Values that originate as `oklch(...)` in the design source are
    pre-converted to sRGB hex once (via a private `Color(hex:)` initializer)
    rather than converted at runtime.
  - `VikunjaFont` — wraps the system Dynamic Type text styles under our own
    names, so a future custom typeface or weight change happens in one place.
  - `VikunjaSpacing` — spacing scale on a 4pt grid (`xxs` through `xxl`).
  - **Toasts** (`Toast/`) — the app-wide toast system. `ToastCenter` is an
    `@Observable`/`@MainActor` queue (one toast on screen at a time; a second
    `show` while one is up waits its turn) that implements `VikunjaCore`'s
    `ToastPresenting` protocol; `ToastView`/`ToastHostModifier` are the actual
    rendering, attached once via `View.toastHost(_:)`. The split exists so a
    ViewModel can depend on the plain `ToastPresenting` protocol (constructor
    injection, like a repository) without ever importing
    `VikunjaDesignSystem` or SwiftUI — the same relationship
    `VikunjaNetworking` has to `VikunjaCore`, just for a UI-facing protocol
    instead of a data one. `AppContainer` owns the single `ToastCenter`
    instance (`container.toastCenter`); `RootView` attaches
    `.toastHost(container.toastCenter)` at the top of the view hierarchy so a
    toast floats above onboarding, every tab, and any sheet. To show a toast
    from a ViewModel: take `toastPresenter: ToastPresenting` via constructor
    injection (pass `container.toastCenter` from the relevant
    `make...ViewModel` factory), then call
    `toastPresenter.show("Task created", style: .success)` — no setup beyond
    that one constructor parameter.

- **`Features/Onboarding`** — the "connect to your instance" screen. Depends only
  on `VikunjaCore`.
  - `ViewModels/InstanceSetupViewModel.swift` — `@Observable`, `@MainActor`.
    Normalizes the typed URL via `InstanceURL`, probes it via
    `InstanceClientFactoryProtocol.makeCapabilityProvider(baseURL:).serverInfo()`
    (confirms it's a real Vikunja instance; the API token itself isn't validated
    against the server yet), then persists via `AccountStoreProtocol`. Takes both
    protocols by constructor injection — no concrete `VikunjaNetworking`/
    `VikunjaAuth` types.
  - `Models/InstanceSetupValidationState.swift` — view-specific state
    (`idle`/`validating`/`success`/`failure(message)`), not a domain model.
  - `Views/InstanceSetupView.swift` — the onboarding form; reports the saved
    account back via an `onConnectionSaved` callback rather than knowing what
    happens next.

- **`Features/Home`, `Features/Projects`, `Features/Search`, `Features/Settings`**
  — one per main tab. Depend on `VikunjaCore` + `VikunjaNavigation` (`Projects`
  also depends on `VikunjaDesignSystem`, now that it has real content — the
  others are still placeholder screens on that front). Each follows the same
  shape: `Views/<Name>View.swift`, `Views/<Name>RootView.swift` (public entry
  point — owns a `NavigationStack` bound to its own `Router<FeatureRoute>`),
  and `Navigation/<Name>Route.swift` (an empty route enum until the feature has
  a screen to push). Only `<Name>RootView` is public; the content view stays
  internal to the package.
  - `Home` confirms the connected instance's name; `Search` is still a bare
    placeholder.
  - `Settings` is mostly placeholder but has one real action: "Update API
    Token" clears the saved connection (via an `onResetConnection` callback
    the app target wires to `AccountStoreProtocol`, behind a confirmation
    dialog), dropping `RootView` back to onboarding.
  - `Projects` is fully built: `ProjectsListViewModel` loads the flat project
    list and arranges it into a parent/child tree by `parentProjectID`;
    `ProjectsView` renders it as an indented, per-project expand/collapsible
    list (rows start **collapsed** — `expandedProjectIDs` is empty until the
    user taps a disclosure chevron, nothing auto-expands on load) inside a
    `Router<ProjectsRoute>`-driven `NavigationStack`. Selecting a project
    pushes `ProjectOverviewViewModel`/`ProjectOverviewView` — subprojects as a
    horizontal card row, the project's own tasks grouped into
    Overdue/Pending/Completed sections behind an All/Pending/Overdue/Completed
    filter. Selecting a task pushes into `Features/Tasks`'s `TaskDetailView`
    (see below) via a type-erased `(VikunjaTask, Project) -> AnyView` closure
    supplied by `ProjectsRootView`'s initializer — `Projects` never imports
    `Tasks` directly; the app target's `AppContainer` is what actually
    supplies that closure, keeping the cross-feature navigation decoupled the
    same way networking is.

- **`Features/Tasks`** — a single task's detail screen: completion toggle, due
  date, priority, labels, subtasks, and dependencies (`dependsOn`/`blocks`, with
  a "Blocked" banner when any `dependsOn` relation is incomplete). Depends on
  `VikunjaCore` + `VikunjaDesignSystem` only — no `VikunjaNavigation` of its
  own, since `TaskDetailView` is always pushed as a leaf screen onto whichever
  feature's stack opened it (`Projects`, today). `TaskDetailViewModel.task`
  starts as whatever was passed in at navigation time (no blank/spinner flash)
  and `load()` refreshes it from the server; `toggleDone()` optimistically
  flips completion, persists it, and carries the previously-loaded
  `subtasks`/`dependsOn`/`blocks` onto the server's response since Vikunja's
  task-update endpoint doesn't return relations (see the `Mappers/` note
  above) — without that, toggling completion would make those sections vanish.

Features should only ever import `VikunjaCore`/`VikunjaNavigation` and depend on
`VikunjaCore`'s protocols — never import `VikunjaNetworking` or `VikunjaAuth`
directly. The `AppContainer` composition root (`vikunja/AppContainer.swift`) is the
only place expected to know about concrete `VikunjaNetworking`/`VikunjaAuth` types
and wire them into the protocol-typed dependencies Features receive. This is what
keeps a Vikunja API change contained to `VikunjaNetworking` instead of rippling
into UI code.

**Top-level navigation** (`vikunja/RootView.swift`, `vikunja/Navigation/`): `RootView`
switches between `InstanceSetupView` (no connected account yet) and `MainTabView`
(a connected account exists). `MainTabView` is the floating, Liquid Glass tab bar —
the default look for `TabView` on iOS 26+ — with one `Tab` per `AppTab` case
(`.home`, `.projects`, `.settings`, plus `.search` using iOS 26's dedicated
`.search` tab role, which renders as a separated glass pill) and a
`QuickAddButton` — a bare circular FAB matching the design mockup — placed via
a plain `.overlay(alignment: .bottomTrailing)`, not `.tabViewBottomAccessory`:
that API always paints a system glass background behind its content and
centers it over the tab bar, which can't be suppressed or anchored to a
corner. `AppTab` and `MainTabView` live in the app target, not a package,
because the `Tab(role:)` / `tabBarMinimizeBehavior` APIs require the iOS 26
SDK, while packages floor at `.iOS(.v17)`.

**Multi-instance / multi-version handling**: since self-hosted instances can be on
very different Vikunja versions with different features enabled, `CapabilityProvider`
hits `GET /api/v1/info` once per session, caches the result, and exposes
`supports(_:)`. Code should branch on capabilities rather than hardcoding server
version comparisons.

`vikunja/` is the composition root: `vikunjaApp.swift` builds the `AppContainer`,
`RootView.swift` switches between onboarding and the main tab bar, and
`Navigation/` holds `AppTab` and `MainTabView` (see above).

## Rules for new code

These are binding for anything added under `Features/`, `VikunjaAuth`, or
`AppContainer` — not just aspirational. See `ARCHITECTURE.md` for the "why"
behind each one.

- **Never import `VikunjaNetworking` from a Feature.** Features depend only on
  `VikunjaCore` protocols and models. Only the composition root (`AppContainer`)
  is allowed to know about concrete `VikunjaNetworking`/`VikunjaAuth` types and
  wire them in.
- **Views use `VikunjaDesignSystem` tokens, not hardcoded values.** Colors go
  through `VikunjaColor`, fonts through `VikunjaFont`, spacing through
  `VikunjaSpacing` — no raw `Color(...)`/`Font(...)` literals or magic-number
  padding in `Features/*` views. Add a new token there first if the one you need
  doesn't exist yet, rather than inlining a one-off value.
- **ViewModels take their dependency as a protocol via constructor injection**
  (e.g. `init(repository: TaskRepositoryProtocol)`), never a concrete networking
  class. Views contain no business logic and no networking knowledge.
- **Each `Features/<Name>` module follows the same internal shape**:
  `Models/` (view-specific state only), `ViewModels/`, `Views/`, `Navigation/`
  (a per-feature `Router<Route>` from `VikunjaNavigation`, typed to a private
  route enum — no direct cross-feature `NavigationLink(destination:)`). The
  package's only public view is `<Name>RootView`, which owns the
  `NavigationStack`/`Router` pair; the app target never touches a feature's
  route enum or `NavigationPath` directly. Exception: a feature that's only
  ever pushed as a leaf screen onto another feature's stack (`Features/Tasks`
  today) has no `Navigation/`/`Router` of its own — it exposes a plain public
  view instead, and the feature that pushes it supplies a type-erased
  `AnyView`-returning closure (built by `AppContainer`) rather than importing
  it directly.
- **No third-party DI framework.** Dependency wiring is a plain `AppContainer`
  with constructor injection.
- **Credentials (JWT, API tokens) live in the Keychain, never `UserDefaults`.**
- **Branch on `CapabilityProvider.supports(_:)`, never on ad-hoc version
  comparisons scattered through feature code.** Version-specific logic, if
  needed, stays inside `VikunjaNetworking` (e.g. a second `Mapper` selected by
  `serverInfo.version`).
- **Tests**: `VikunjaCore` tests need no networking. `VikunjaNetworking` tests use
  real JSON fixtures (contract tests) rather than hand-written minimal payloads.
  `Features/*` tests use fake implementations of `VikunjaCore` protocols, not HTTP
  mocks.

## Conventions

- English only — no Spanish in code, comments, strings, or test fixtures (this is
  an open-source project).
- Conventional Commits, small/atomic commits — check `git log` for the established
  granularity (roughly one type/file-group per commit). Single-line subject only
  (no body, no trailers, no `Co-Authored-By`).
- Swift 6 language mode / strict concurrency in both packages
  (`swift-tools-version: 6.0`). Types crossing the `APIClient` boundary as a
  `Response` generic must be `Sendable`.
- Packages declare `iOS(.v17)` as their platform floor (for portability); the app
  target itself currently deploys at `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, well
  above that floor.
