# Adding a Platform

Visual MD treats a platform as a bundle of capabilities supplied at startup.
The reader and its use cases do not branch on an operating system; the
composition root asks for `PlatformAdapters` once and wires the returned
implementations into the same application (`lib/main.dart:46-110`).

This guide describes the current bundle, including standalone Markdown and
durable workspace support. A platform is ready when those capabilities work in
its real authority model, not merely when the Flutter target compiles.

## Start with the platform family

Two families exist today:

- The web family uses `package:web` and `dart:js_interop`.
- The desktop family uses `dart:io` and serves macOS and Windows.

The conditional export in
`lib/infrastructure/platform/platform.dart:3-5` selects a family at compile
time. A target that fits an existing family normally extends that
implementation only where its behavior differs. A target with an incompatible
runtime or authority model gets a new family and one new conditional branch.

This distinction keeps platform work proportional. Windows, for example,
shares the desktop scanners and workspace files; its unverified work is native
build validation and platform-specific chrome, not a second copy of the reader.

## Scaffold the Flutter target

From the repository root:

```sh
flutter create . --project-name visualmd --platforms <target> --org com.visualmd --no-pub
```

Flutter generates the native host folder and may refresh its project metadata.
Review that generated diff before adding Visual MD-specific code, so generator
changes stay distinguishable from adapter decisions.

## Implement the capability bundle

`PlatformAdapters` is the inventory the composition root consumes
(`lib/infrastructure/platform/platform_adapters.dart:11-55`):

| Concern | Capability |
|---------|------------|
| Sources | folder and standalone-Markdown scanners, pickers, and drop streams |
| Workspaces | `WorkspaceFiles` for open/save and `WorkspaceSourceAccess` for restoring, reconnecting, and removing local authority |
| Host commands | a typed native-menu command stream, external-link opening, and launch options |
| Window integration | the drop-region wrapper, top-bar geometry, and optional window-drag wrapper |
| Reader-local data | small preferences, theme documents, and the user-theme location |

For an existing family, reuse its answers and add a platform branch only for a
real difference. The macOS title bar is one example
(`lib/infrastructure/platform/platform_io.dart:26-36`,
`lib/infrastructure/platform/platform_io.dart:98-110`). For a new family,
implement the complete interface and let unsupported host features return a
neutral value such as an empty command stream or identity wrapper, as the web
family does (`lib/infrastructure/platform/platform_web.dart:68-103`).

If a target exposes a genuinely new product capability, begin with the use
case that needs it and add a narrow application port. The adapter then
implements that port. Platform objects and packages remain in
`infrastructure/`.

## Preserve source identity and authority

`FolderRef` and `MarkdownRef` are process-scoped handles. The application can
pass them to scanners without learning whether they represent a path, browser
handle, or sandbox bookmark. Registries keep the platform object on the
adapter side (`lib/infrastructure/folder_registry.dart:6-20`).

Workspaces add a second requirement: reopen the same durable source identity
without putting machine authority into shared JSON. Implement
`WorkspaceSourceAccess` with the platform's local mechanism — paths and
security-scoped bookmarks on desktop, permission-bearing handles in the
browser — and keep it keyed by workspace and source identity. See
[Workspace Lifecycle](../02-application/09-workspace-lifecycle.md) before
changing this boundary.

Scanners should read only Markdown outside hidden folders. They may consult
the domain's `MarkdownFile` and `HiddenFolders` rules, but should not create a
second definition of what belongs in a library.

## Configure the native host

Native configuration belongs in the generated platform folder. Check at
least:

- product name, bundle/application identity, and launcher artwork;
- file-open, save, and drag/drop integration;
- sandbox or filesystem permissions;
- native File-menu commands and keyboard equivalents where the host supports
  application menus;
- window chrome and accessibility semantics.

On macOS, user-selected read/write access and app-scoped bookmarks are declared
in `macos/Runner/Release.entitlements:5-10`. Network access remains available
for non-bundled family names used by custom themes. The hidden title bar and
native File menu are configured in the host before Flutter renders; see
[macOS](../06-platforms/02-macos.md).

## Test the boundary that can fail

A source scanner test should use a real temporary tree and cover Markdown at
depth, ignored non-Markdown, hidden folders, malformed bytes, and unknown refs.
`test/infrastructure/local_folder_scanner_test.dart:11-94` is the desktop
example.

Workspace tests should cover the platform's actual write and authority
behavior. Desktop tests keep the platform-selected path intact, exercise the
macOS native-write message, and retain a last-good fallback copy
(`test/infrastructure/desktop_workspace_files_test.dart:9-81`), while shared
application tests cover transactional restoration, unavailable sources,
standalone absorption, explicit web downloads, and reconnection
(`test/application/workspace_use_cases_test.dart:186-596`). Native command
bridges also deserve a focused test
(`test/infrastructure/desktop_commands_test.dart:9-27`).

## Verify on the target

Before describing a platform as supported:

1. Run `flutter test test/architecture` and confirm platform imports remain in
   `infrastructure/`.
2. Run the focused scanner, workspace, and host-command tests.
3. Run `flutter build <target>` on the target's real toolchain.
4. Open a folder and a standalone Markdown file, save and reopen a workspace,
   reconnect an unavailable source, and try both drag/drop and native menus.
5. Run `bin/tools/validate.sh` and record any host-specific check that CI cannot
   reproduce.

The Windows target is currently scaffolded but has not completed this native
verification on Windows. The source and portable tests are useful evidence;
they are not a substitute for building and exercising the host.
