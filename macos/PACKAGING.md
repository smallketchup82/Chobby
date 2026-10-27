# macOS client and application packaging

The first stage is a source-built development client. It is not yet a
redistributable `.app`. The native engine, system Mono installation and
Homebrew libraries still belong to the development machine.

## Build and run the development client

Use sibling checkouts `chobby/` and `infrastructure/` inside the port workspace.
From the workspace root:

```sh
./chobby/macos/build-client.sh
./run-chobby.sh
```

The build script compiles `ChobbyLauncher/ChobbyLauncher.csproj` with Mono
MSBuild and packages this Chobby source as `Chobby macos-source`. The generated
`build/resources/games/Chobby-macos.sdz` replaces the downloaded lobby for this
launch. It does not replace the downloaded Zero-K game or its archive checksum.

| Artifact | Purpose |
| --- | --- |
| `build/client/` | Our `Zero-K.exe`, managed dependencies, Steam library and import mappings |
| `build/resources/` | Read-only lobby archive and macOS game adaptations |
| `build/client-build.json` | Source revisions, dirty-state flags and lobby archive hash |
| `native-data/` | Existing development settings, content downloads and logs |

The source game adaptations in `macos/game-data/` contain the trackpad preset,
Retina/FPS options, CAS pixel capture and legacy panel configuration. These
replace the loose files previously patched into `native-data/`; their backups
are in the workspace's `diagnostics/legacy-local-widgets/` directory.

The launcher accepts these environment variables so installation resources and
writable user data can be separated without a new launcher framework:

| Variable | Meaning |
| --- | --- |
| `ZEROK_DATA_DIR` | Writable settings, downloads, replays and logs |
| `ZEROK_RESOURCE_DIR` | Read-only Spring data directory with the bundled lobby and adaptations |
| `ZEROK_ENGINE_PATH` | Explicit native engine executable; enables bundle launch mode |
| `ZEROK_CHOBBY_NAME` | Internal name of the bundled lobby, currently `Chobby macos-source` |

Bundle launch mode skips the Windows launcher UI, upstream launcher/lobby/engine
self-updates and old portable config deployment. Steam authentication and the
existing wrapper protocol remain active. Game/map downloads still use that
protocol. The normal launcher path remains available when these overrides are
absent. `SteamAppId` and `SteamGameId` are set to `334920` by the development
runner.

The launcher remains an Intel Mono process because the matching Steamworks.NET
11 macOS Steam library is Intel. The engine and AI are native ARM64. Removing
Rosetta from the helper requires a separate Steam binding/runtime update.

`engine-vsync.patch` records the presenter and configuration changes for the
current July macOS engine. It forces interval `1` and requests a synchronized
SDL Metal presenter. It applies on top of the existing renderer/Retina port.
`luajit macos/check-settings.lua` checks both macOS platform names and verifies
that Windows/Linux retain their frame limiter controls.

The macOS source changes and build tooling were implemented with OpenAI Codex
assistance. Runtime smoke tests use the local Apple Silicon engine and Steam.

## Next stage: the self-contained application

Use this layout when implementing the distribution build:

```text
Zero-K.app/Contents/
  Info.plist
  MacOS/Zero-K                 application entry point
  Helpers/                    Mono launcher/runtime and Steam helper assets
  Resources/engine/           native spring, matching AI, base and fonts
  Resources/data/             Chobby archive and macOS game adaptations
  Frameworks/                 engine, SDL3, Mesa, Vulkan and compiler runtimes
  Resources/licenses/         notices and matching source/build references
```

The entry point should derive paths from its bundle, select
`~/Library/Application Support/Zero-K` for writable data, seed only missing
defaults, set the four path variables above, then start the bundled helper.
The engine should own the visible game window; the helper should have no
separate Dock presence. Application updates must replace a compatible set of
engine, lobby and launcher resources without overwriting user settings.

Remaining distribution work:

- Bundle the Mono runtime and every non-system native dependency, including
  SDL3 loaded indirectly by sdl2-compat and libraries loaded by Mesa or the AIs.
- Rewrite dylib references, rpaths, the Vulkan ICD path and executable-relative
  Mesa lookup. Audit with `otool`, then run after moving the bundle and hiding
  developer dependencies. The current engine packaging script is a starting
  point, not a verified app packager.
- Replace development symlinks to the engine tree and `zero-k-portable`; include
  matching AI profiles, base content and fonts. Use normal first-run downloads
  for game/maps instead of copying the developer's content cache.
- Keep accounts, Steam tickets, chat logs, replays, caches and local config out
  of the build inputs. Include only source-controlled defaults.
- Handle missing Steam/Rosetta cleanly and decide whether optional Discord RPC,
  Linux idle detection and text-to-speech should be omitted or implemented.
- Collect redistribution notices and source references for the exact runtime,
  Steam, renderer and game assets being shipped.
- Sign nested binaries, sign/notarize the app, and test a downloaded build on a
  clean Apple Silicon Mac without Mono, Homebrew or developer tools.

Only after relocation and clean-machine testing should the app become the
primary supported launch method and be shared with friends.
