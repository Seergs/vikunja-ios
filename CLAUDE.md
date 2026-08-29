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
cd Packages/Features/Home && swift build && swift test
cd Packages/Features/Projects && swift build && swift test
cd Packages/Features/Tasks && swift build && swift test
cd Packages/Features/Settings && swift build && swift test
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
    `TaskRelation`, `RelationKind`, `TaskComment`, `InstanceAccount`,
    `InstanceURL`, `ToastStyle`). `InstanceAccount` holds only
    id/displayName/baseURL/createdAt — no `authMethod` field, since only API
    token auth is modeled today. `InstanceURL.normalize(_:)` turns a bare
    domain or full URL the user typed into the scheme+host `URL` the
    networking layer expects as `baseURL`. `TaskRelation` is a thin
    id/title/isDone/projectID summary (not a full recursive `VikunjaTask`) used
    for `VikunjaTask.subtasks`, `.dependsOn`, `.blocks`, and `.otherRelations`
    — Vikunja represents every relation the same way, as a "related task"
    keyed by relation kind. `RelationKind` is that key: `subtask`/`blocked`/
    `blocking` map onto the three named `VikunjaTask` fields (they get distinct
    UI — checkboxes, the "Blocked" banner); every other kind (`related`,
    `precedes`, `duplicateof`, ...) is carried generically in
    `VikunjaTask.otherRelations` (`[RelationKind: [TaskRelation]]`).
    `TaskComment` is id/comment/author/created/updated — a task's comment
    thread, kept separate from `VikunjaTask` itself since it's loaded and
    posted through its own endpoint.
  - `Protocols/` — the contracts Features are meant to depend on
    (`TaskRepositoryProtocol`, `ProjectRepositoryProtocol`,
    `LabelRepositoryProtocol`, `TaskRelationRepositoryProtocol`,
    `TaskCommentRepositoryProtocol`, `AuthServiceProtocol`,
    `AccountStoreProtocol`, `InstanceClientFactoryProtocol`,
    `ToastPresenting`). `TaskRepositoryProtocol` and `ProjectRepositoryProtocol`
    now cover full CRUD; `TaskRepositoryProtocol` also has
    `searchTasks(query:)` (account-wide, not project-scoped — for the relation
    picker). `LabelRepositoryProtocol` covers label CRUD plus attach/detach
    against a task; `TaskRelationRepositoryProtocol` is just add/remove a
    relation of a given `RelationKind`; `TaskCommentRepositoryProtocol` is
    fetch/add/update/delete for one task's comments (only fetch and add are
    wired into `Features/Tasks` today — see below). `AccountStoreProtocol` is
    full multi-account CRUD (`fetchAccounts`/`addAccount`/`updateAccount`/
    `removeAccount`/`setActiveAccount`/`token(forAccountID:)`), not just a
    single saved connection.
  - `Capabilities/` — `VikunjaServerInfo`, `CapabilityProvider`, `VikunjaFeature`:
    the runtime feature-detection layer (see below).
  - `Errors/` — `VikunjaError`, the domain-level error type everything surfaces.

- **`VikunjaNetworking`** — the only module that knows Vikunja speaks HTTP/JSON.
  Depends on `VikunjaCore`.
  - `Client/` — generic transport: `APIClient` protocol, `Endpoint` struct
    (with an `Endpoint.encoding(path:method:body:)` helper that JSON-encodes a
    body), and the concrete `URLSessionAPIClient` actor (maps HTTP status codes
    to `VikunjaError`).
  - `Endpoints/VikunjaEndpoints.swift` — the single file that knows Vikunja's actual
    REST routes (`/api/v1/...`). This is where a real API change gets fixed.
    Covers `/info`, login, full task + project CRUD (**create is `PUT`**, update
    is `POST` — Vikunja's convention, not a typo), label CRUD plus task/label
    association (`/tasks/{id}/labels`), task relation add/remove
    (`/tasks/{id}/relations`), task comment CRUD (`/tasks/{id}/comments`), and
    account-wide task search (`GET /api/v1/tasks?s=`
    — note `/tasks`, **not** the older `/tasks/all`; see the doc comment on
    `searchTasks` for the version nuance).
  - `DTOs/` — `Codable` structs mirroring the raw JSON, tolerant of optional/missing
    fields. Field names are best-effort and **must be verified against a live
    instance's swagger docs (`/api/v1/docs`)** before pointing this at a real server.
    `RelatedTaskDTO` mirrors one entry of `TaskDTO.relatedTasks` (JSON key
    `related_tasks`), a `[String: [RelatedTaskDTO]]` keyed by relation kind
    (`"subtask"`, `"blocked"`, `"blocking"`, ...). `LabelDTO`, `TaskLabelDTO`
    (attach-label body), `CreateTaskRelationDTO` (add-relation body),
    `CommentDTO` (a task comment; the body arrives as the rich-text editor's
    HTML — see `Mappers/` below). `JSONValue`
    is a shape-agnostic JSON box used only for `TaskDTO` fields whose real
    structure isn't verified (`reminders`, `assignees`) — see the next bullet.
    `TaskDTO` carries a large tail of fields it **never** populates from the
    domain model (`doneAt`, `startDate`, `reminders`, `percentDone`,
    `hexColor`, ...); they exist purely so an update can round-trip the
    server's current state untouched.
  - `Mappers/` — DTO → domain model translation. `TaskRelationMapper` maps one
    `RelatedTaskDTO` to a `TaskRelation`; `TaskMapper` reads `subtasks`/
    `dependsOn`/`blocks`/`otherRelations` out of `TaskDTO.relatedTasks` by kind
    (unrecognized kind strings are dropped, not fatal). `LabelMapper` for
    `Label`; `CommentMapper` for `TaskComment`. Two things about updates:
    - Vikunja manages relations and labels through their own endpoints rather
      than the task update body, so `TaskMapper`'s update-response mapping
      doesn't carry them back — see `TaskDetailViewModel.persist(previous:)` in
      `Features/Tasks` for how callers preserve the previously-loaded
      relations/labels across an update instead of losing them.
    - Vikunja's task update is a **full replace**: any field the request body
      omits is reset to zero/null server-side. `VikunjaTaskRepository.update`
      therefore `GET`s the current task first and `TaskMapper.merge(_:onto:)`
      overwrites only the fields `VikunjaTask` tracks, leaving everything else
      (including fields the domain model doesn't represent) exactly as the
      server last reported it.
  - `Repositories/` — concrete implementations of `VikunjaCore`'s protocols
    (`VikunjaTaskRepository`, `VikunjaProjectRepository`, `VikunjaLabelRepository`,
    `VikunjaTaskRelationRepository`, `VikunjaTaskCommentRepository`,
    `VikunjaCapabilityProvider`, `VikunjaAuthService`,
    `VikunjaInstanceClientFactory`). These are what eventually get injected
    into Features. `VikunjaInstanceClientFactory` builds one of these per
    screen call — see `InstanceClientFactoryProtocol` — from a `baseURL` plus
    a `tokenProvider` closure; there's no long-lived per-account client.

- **`VikunjaAuth`** — multi-account/instance storage. Depends on `VikunjaCore`.
  - `KeychainAccountStore` — implements `AccountStoreProtocol`: the account list,
    each account's bearer token (keyed by account id, in its own Keychain item so
    removing one account never touches another's secret), and the active-account
    pointer, all in the Keychain, never `UserDefaults`. Adding an account makes it
    the active one; updating one can rotate its token or leave it untouched;
    removing one deletes both its metadata and its token item.
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
  - `VikunjaColor` — `brandPrimary`; `VikunjaColor.Priority` (`urgent`/`high`/
    `medium`/`low`); `Surface` (`card`/`field`/`page` grouped-content
    backgrounds, backed by adaptive iOS system colors — see
    `Color+Platform.swift`); `textSecondary`/`textTertiary` (a darker, more
    legible gray scale than the system `.secondary`/`.tertiary`); `Semantic`
    (`success`/`danger` plus darker `successText`/`dangerText` for text drawn
    on a tinted banner); and `SwatchPalette` (preset hex strings offered when
    picking a color for a label or project the user is creating). Values that
    originate as `oklch(...)` in the design source are pre-converted to sRGB
    hex once (via a private `Color(hex:)` initializer) rather than converted at
    runtime. `Color(vikunjaHex:)` (public) parses an API `hex_color` string
    off a `Project`/`Label`, returning `nil` for unset/malformed so callers
    fall back to a token.
  - `VikunjaFont` — wraps the system Dynamic Type text styles under our own
    names, so a future custom typeface or weight change happens in one place.
  - `VikunjaSpacing` — spacing scale on a 4pt grid (`xxs` through `xxl`).
  - `VikunjaRadius` — corner-radius scale (`sm`/`md`/`lg`) for fields, cards,
    buttons, sheet corners.
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

- **`Features/Onboarding`** — the "connect to your instance" screen. Depends on
  `VikunjaCore` + `VikunjaDesignSystem`.
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
  — one per main tab. `Search` still depends only on `VikunjaNavigation`
  (bare placeholder — takes no domain types); `Home`, `Projects`, and
  `Settings` all depend on `VikunjaCore` + `VikunjaNavigation` +
  `VikunjaDesignSystem`, with real content behind each. Each follows the same
  shape: `Views/<Name>View.swift`, `Views/<Name>RootView.swift` (public entry
  point — owns a `NavigationStack` bound to its own `Router<FeatureRoute>`),
  and `Navigation/<Name>Route.swift` (an empty route enum until the feature has
  a screen to push). Only `<Name>RootView` is public; the content view stays
  internal to the package. `Home`, `Projects`, `Settings`, and `Tasks` also have
  a `Models/ScreenLoadState.swift` (a shared `idle`/`loading`/`loaded`/
  `failure(String)` request-lifecycle enum, not a domain model) and a
  `Support/VikunjaError+DisplayMessage.swift` (per-feature user-facing error
  copy).
  - `Home` is the "Today" screen, fully built: `TodayViewModel` fetches every
    project (`ProjectRepositoryProtocol.fetchProjects`) and then every
    project's tasks concurrently (`TaskRepositoryProtocol.fetchTasks`,
    dropping a project whose fetch fails rather than failing the whole
    screen), flattening them into one account-wide list — unlike `Projects`'
    screens, nothing here scopes the fetch to a single project. `TodayView`
    groups the merged tasks by due date into Overdue/Today/Upcoming sections
    (ascending by due date within a section) behind an
    All/Overdue/Today/Upcoming filter chip row; tasks with no due date never
    appear here, only inside their own project. Each row shows the task's
    project (color dot + name, looked up from `projectsByID` since a task
    only carries its `projectID`), an "Overdue" label or due date, a link
    icon when the task `hasRelations`, and up to two label pills. The
    completion toggle is optimistic with rollback
    (`TodayViewModel.toggleDone`); tapping a row pushes `Features/Tasks`'
    `TaskDetailView` via the same type-erased closure pattern `Projects` uses
    (see below). Supports pull-to-refresh.
  - `Settings` is fully built as multi-account management, not just a
    single reset action: `SettingsView` is a landing screen showing the
    active connection's name with a "Connections" row that pushes
    `ConnectionsListView`/`ConnectionsListViewModel` — every saved
    `InstanceAccount`, with a checkmark on the active one;
    `setActive(_:)` calls `AccountStoreProtocol.setActiveAccount` and fires
    an `onActiveAccountChanged` callback. Tapping an account (or a toolbar
    "+") pushes `ConnectionFormView`/`ConnectionFormViewModel` in `.edit`/
    `.create` mode (`ConnectionFormMode`) — the same normalize-URL-then-probe-
    `/api/v1/info` flow as `Onboarding`'s `InstanceSetupViewModel`, plus
    `deleteConnection()` (refuses, with a toast, to delete the last remaining
    account) and, in `.edit` mode, an async `load()` that fills in the
    existing token from the Keychain after the name/URL render immediately.
    Saving or deleting fires `onActiveAccountChanged` too, since either can
    change which account is active or edit the active one's own address.
    `SettingsView` also has a "Manage Labels" row that pushes
    `ManageLabelsView`/`ManageLabelsViewModel` (route `.manageLabels`): the
    account-wide label list (`LabelRepositoryProtocol.fetchLabels`, sorted by
    title) with per-row swatch + title, swipe-to-delete behind a
    `confirmationDialog` (`deleteLabel` — optimistic removal with rollback),
    and create / rename+recolor through `LabelEditorSheet` — a compact
    `.sheet` (not a route) in `.create`/`.edit(Label)` mode
    (`LabelEditorMode`) with a title field and preset `VikunjaColor.SwatchPalette`
    swatches only, no free-form picker. `createLabel`/`updateLabel` surface a
    toast; `updateLabel` is optimistic with rollback. This is label
    management only — nothing here attaches a label to a task (that's
    `Features/Tasks`' `LabelPickerSheet`). `AppContainer.makeManageLabelsViewModel(account:)`
    wires the `LabelRepository` through `InstanceClientFactoryProtocol`.
  - `Projects` is fully built: `ProjectsListViewModel` loads the flat project
    list and arranges it into a parent/child tree by `parentProjectID`, then
    fetches each project's own tasks concurrently to populate
    `taskSummaries` (`ProjectTaskSummary`: done/total counts, dropped rather
    than failing the screen if a project's fetch fails) for a per-row
    completion indicator; `ProjectsView` renders the tree as an indented,
    per-project expand/collapsible list (rows start **collapsed** —
    `expandedProjectIDs` is empty until the user taps a disclosure chevron,
    nothing auto-expands on load) inside a `Router<ProjectsRoute>`-driven
    `NavigationStack`. A toolbar "+" opens
    `CreateProjectSheetView`/`CreateProjectViewModel` — a compact sheet for
    title + color swatch + parent project (parent defaults to "None"/root, or
    is preset when opened from within a project), creating via
    `ProjectRepositoryProtocol.create` and surfacing a success toast.
    Selecting a project pushes `ProjectOverviewViewModel`/
    `ProjectOverviewView` — subprojects as a horizontal card row (each with
    its own recursively-fetched completion count), the project's own tasks
    grouped into Overdue/Pending/Completed sections (ascending by due date)
    behind an All/Pending/Overdue/Completed filter. A task row's completion
    toggle persists optimistically; a long-press context menu offers
    "Delete", which goes through a confirmation dialog to
    `ProjectOverviewViewModel.delete` (`TaskRepositoryProtocol.delete` +
    toast). Selecting a task pushes into `Features/Tasks`'s `TaskDetailView`
    (see below) via a type-erased `(VikunjaTask, Project) -> AnyView` closure
    supplied by `ProjectsRootView`'s initializer — `Projects` never imports
    `Tasks` directly; the app target's `AppContainer` is what actually
    supplies that closure (and the `CreateProjectViewModel` factory), keeping
    the cross-feature navigation and repository wiring decoupled the same
    way networking is. `Home` reuses this exact same closure pattern for its
    own push into `TaskDetailView`.

- **`Features/Tasks`** — two things: a single task's detail screen
  (`TaskDetailView`/`TaskDetailViewModel`) and the quick-add task flow
  (`QuickAddSheetView`/`QuickAddTaskViewModel`). Depends on `VikunjaCore` +
  `VikunjaDesignSystem` only — no `VikunjaNavigation` of its own, since neither
  view owns push navigation: `TaskDetailView` is always pushed as a leaf screen
  onto whichever feature's stack opened it (`Home` or `Projects`, today), and
  `QuickAddSheetView` is a `.sheet` presented by whoever owns the FAB
  (`MainTabView`).
  - **Detail screen**: an inline-editable title and description (see below),
    completion toggle, due date, priority, labels, subtasks (read-only
    checklist), a combined "Relations" section covering `dependsOn`/`blocks`
    plus every `otherRelations` kind (with a "Blocked" banner when any
    `dependsOn` relation is incomplete), and a "Comments" section (see
    below). `TaskDetailViewModel.task` starts as whatever was passed in at
    navigation time (no blank/spinner flash) and `load()` refreshes it from
    the server; the screen also supports pull-to-refresh. All edits are
    optimistic with rollback: `toggleDone()`/`setDueDate()`/`setPriority()`/
    `setTitle()`/`setDescription()` go through `persist(previous:)`, which
    carries the previously-loaded relations/labels onto the server's
    response since Vikunja's task-update endpoint doesn't return them (see
    the `Mappers/` note above) — without that, editing would make those
    sections vanish. Title and description are edited inline (not a
    separate sheet) and committed via a nav bar checkmark, not the keyboard's
    return key, matching Notes/Reminders.
  - **Labels**: `LabelPickerSheet` (a `.searchable` list) toggles membership
    via `LabelRepositoryProtocol.addLabel`/`removeLabel`, and can
    create-and-attach a new label on the fly (`createAndAddLabel`); `allLabels`
    is loaded lazily.
  - **Relations**: a two-step sheet — pick a `RelationKind`, then pick the
    other task. The task picker searches account-wide
    (`TaskRepositoryProtocol.searchTasks`) and, before the user types,
    suggests the current task's own project's other tasks (most relations are
    intra-project). Tapping an existing relation row resolves the full task +
    its project (`loadRelatedTask`) and pushes another `TaskDetailView` for it
    — `makeDetailViewModel` reuses this view model's own dependencies so the
    recursion needs nothing from `AppContainer`.
  - **Comments**: `loadComments()` runs alongside `load()` but reports into
    its own `commentsLoadState`, so a comments-fetch failure doesn't block the
    rest of the screen. `addComment(_:)` posts via
    `TaskCommentRepositoryProtocol.addComment` and appends the server's
    response (no optimistic placeholder, since a comment's id/author/
    timestamps only exist once the server assigns them). Comment bodies
    arrive as the Vikunja rich-text editor's HTML output; `CommentTextFormatter`
    strips that down to plain text since this feature has no rich-text
    renderer yet. A comment row's context menu offers "Edit Comment"
    (`editComment(_:newText:)` — `EditCommentSheet`, prefilled with the
    plain-text body, persists via `TaskCommentRepositoryProtocol.updateComment`
    and swaps in the server's response; no optimistic placeholder, same as
    `addComment`) and "Delete Comment" (`deleteComment(_:)`, optimistic removal
    with rollback behind a confirmation dialog).
  - `TaskDetailViewModel` takes `task` + `project` + **five** repository
    protocols (`TaskRepositoryProtocol`, `LabelRepositoryProtocol`,
    `TaskRelationRepositoryProtocol`, `TaskCommentRepositoryProtocol`,
    `ProjectRepositoryProtocol`) + a `ToastPresenting`, all via constructor
    injection.
  - **Quick-add** (`QuickAddTaskViewModel`): title + project + priority only
    (matching the mockup's `AddTaskSheet`). Opened from the tab bar FAB with
    no project context, so `selectedProjectID` starts `nil` and `canSave`
    stays false until one is picked. Creates via `TaskRepositoryProtocol.create`
    and shows a success toast.

Features should only ever import `VikunjaCore`/`VikunjaNavigation`/
`VikunjaDesignSystem` and depend on `VikunjaCore`'s protocols — never import
`VikunjaNetworking` or `VikunjaAuth` directly. The `AppContainer` composition
root (`vikunja/AppContainer.swift`) is the only place expected to know about
concrete `VikunjaNetworking`/`VikunjaAuth` types and wire them into the
protocol-typed dependencies Features receive. It exposes one `make…ViewModel`
factory per screen; a screen scoped to one instance takes `account:` and each
factory builds its repositories through `InstanceClientFactoryProtocol` with a
`tokenProvider` closure that re-reads that account's bearer token from
`AccountStoreProtocol` **per request** (so a rotated/removed token is never
cached) — `Settings`' account-management factories
(`makeConnectionsListViewModel`, `makeConnectionFormViewModel`) are the
exception, since they operate across every saved account rather than one.
Every factory passes the single `container.toastCenter` wherever a
`ToastPresenting` is needed. This is what keeps a Vikunja API change contained
to `VikunjaNetworking` instead of rippling into UI code.

**Top-level navigation** (`vikunja/RootView.swift`, `vikunja/Navigation/`): `RootView`
switches between `InstanceSetupView` (no saved account yet) and `MainTabView`
(the active account, once one exists). It re-reads the active account from
`AccountStoreProtocol` on launch and again whenever `Settings`' connection
screens report `onAccountsChanged` (switching accounts, deleting the active
one, or editing its own address); `MainTabView` is rendered `.id(connectedAccount)`
so any of those changes tears down and rebuilds the whole tab shell against
the new account rather than trying to mutate view models built against the
old `baseURL` in place. Deleting the last saved account surfaces here too:
the re-read comes back `nil` and `RootView` falls back to onboarding.
`MainTabView` is the floating, Liquid Glass tab bar —
the default look for `TabView` on iOS 26+ — with one `Tab` per `AppTab` case
(`.home`, `.projects`, `.settings`, plus `.search` using iOS 26's dedicated
`.search` tab role, which renders as a separated glass pill) and a
`QuickAddButton` — a bare circular FAB matching the design mockup — placed via
a plain `.overlay(alignment: .bottomTrailing)`, not `.tabViewBottomAccessory`:
that API always paints a system glass background behind its content and
centers it over the tab bar, which can't be suppressed or anchored to a
corner. The FAB presents `Tasks`' `QuickAddSheetView` as a `.sheet`
(`container.makeQuickAddTaskViewModel(account:)`). `AppTab` and `MainTabView`
live in the app target, not a package,
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
  `VikunjaSpacing`, corner radii through `VikunjaRadius` — no raw
  `Color(...)`/`Font(...)` literals or magic-number padding in `Features/*`
  views. Add a new token there first if the one you need doesn't exist yet,
  rather than inlining a one-off value.
- **ViewModels take their dependency as a protocol via constructor injection**
  (e.g. `init(repository: TaskRepositoryProtocol)`), never a concrete networking
  class. A screen that needs several takes one protocol parameter each (e.g.
  `TaskDetailViewModel`'s five repositories), plus `ToastPresenting` for
  user-facing feedback. Views contain no business logic and no networking
  knowledge.
- **Each `Features/<Name>` module follows the same internal shape**:
  `Models/` (view-specific state only), `ViewModels/`, `Views/`, `Navigation/`
  (a per-feature `Router<Route>` from `VikunjaNavigation`, typed to a private
  route enum — no direct cross-feature `NavigationLink(destination:)`). The
  package's only public view is `<Name>RootView`, which owns the
  `NavigationStack`/`Router` pair; the app target never touches a feature's
  route enum or `NavigationPath` directly. Exception: a feature whose screens
  are only ever pushed as a leaf onto another feature's stack or presented as a
  `.sheet` (`Features/Tasks` today — `TaskDetailView` and `QuickAddSheetView`)
  has no `Navigation/`/`Router` of its own — it exposes plain public views
  instead, and the feature that pushes a leaf screen supplies a type-erased
  `AnyView`-returning closure (built by `AppContainer`) rather than importing
  it directly. (`TaskDetailView` does push a nested copy of *itself* for a
  tapped relation, via `navigationDestination(item:)` onto the host stack —
  that's intra-feature, so no new `Router` is needed.)
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
- **Commit messages: STRICT format** — Conventional Commits style, single line only.
  Format: `type(scope): description` (e.g., `feat(projects): add edit functionality`).
  RULES:
  - ONE line only. NO body, NO blank lines, NO trailers of any kind.
  - NO `Co-Authored-By`, NO `Claude-Session`, NO multi-line footers.
  - NO HEREDOC, NO git commit with `<<'EOF'` — use `-m` with quoted string only.
  - Keep subject under 72 characters.
  - Types: `feat`, `fix`, `refactor`, `docs`, `test`, `chore`, `perf`.
  - Small/atomic commits — check `git log` for established granularity (roughly one
    type/file-group per commit).
- Swift 6 language mode / strict concurrency in both packages
  (`swift-tools-version: 6.0`). Types crossing the `APIClient` boundary as a
  `Response` generic must be `Sendable`.
- Packages declare `iOS(.v17)` as their platform floor (for portability); the app
  target itself currently deploys at `IPHONEOS_DEPLOYMENT_TARGET = 26.2`, well
  above that floor.
