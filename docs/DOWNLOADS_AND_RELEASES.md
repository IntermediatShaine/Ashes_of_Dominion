# Downloadable game builds and release procedure

**Players:** [Windows x64 ZIP](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases/download/preview/Ashes-of-Dominion-Windows-x64.zip) · [Linux x86_64 ZIP](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases/download/preview/Ashes-of-Dominion-Linux-x64.zip) · [Releases page](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases). These links first become functional once the new workflow on main has published its initial successful preview.

The builds are **portable playable prototypes**, not installers. Download your platform's ZIP, extract every file into a folder, and run the executable. Keep the `.pck` file alongside it. Players do **not** need to install Godot, compile the game, or clone GitHub.

## Automatic preview

[Build downloadable game](https://github.com/IntermediatShaine/Ashes_of_Dominion/actions/workflows/distribute-game.yml) runs when game code or its workflow changes on `main`, on suitable PRs, when a `v*` version tag is pushed, or when manually invoked in GitHub Actions.

- PR and manual runs create downloadable **Actions artifacts for reviewers only**, not public releases.
- A passing `main` run creates or updates the public `preview` prerelease and its intentionally moving Git tag. Its direct ZIP URLs remain stable. Failed CI does not update the last published preview.
- A passing version tag (e.g. `v0.1.0`) creates a **versioned release**. The tag must identify a commit in main's history; existing versioned release assets are never silently replaced.
- Download ZIPs include a START_HERE.txt with player instructions. The release includes SHA256SUMS.txt for both ZIP assets.

The player has to extract ZIPs; the project does not currently include a native installer, auto-updater, signed Windows EXE, Apple/macOS build, mobile build, or web build. A Windows SmartScreen warning is possible for an unsigned build; a Linux extraction utility may require users to run `chmod +x` before launching.

## CI gates before release publication

The workflow installs the exact official Godot 4.5.1 standard editor via the existing SHA-512 checked installer, runs the project test suite, and downloads the exact matching official non-.NET export templates. The full upstream template package (roughly 1.36 GB) is SHA-256 checked against the official release asset digest.

`game/tools/build_distributions.sh` extracts only the required Windows/Linux x64 release templates, imports and exports the real game to separate executable + `.pck` pairs, smoke-runs the **exported Linux game** headlessly, packages both ZIPs, and produces hashes. A separate Windows 2022 job extracts and launches the **exported Windows game** headlessly. The publish job independently verifies ZIP checksums and only then updates the public release.

These checks catch packaging/boot errors; they do not replace full manual human gameplay acceptance. The existing reliability workflow remains separate.

## Versioned releases for maintainers

1. Merge game changes after review. Verify the main CI checks and the automatically updated preview.
2. Create a Git tag such as `v0.1.0` **on a commit already in main**, then push it to GitHub. A tag push triggers the distribution workflow for that precise commit.
3. The successful tagged run publishes a named release under [Releases](https://github.com/IntermediatShaine/Ashes_of_Dominion/releases), with both ZIP files and checksums.
4. Prefer sharing the versioned release URL when you need a frozen/reproducible download; use the `preview` download URLs for the newest playable development build.

No signing keys or export secrets are committed. The tracked `game/export_presets.cfg` contains ordinary platform options, while `.godot/export_credentials.cfg` stays untracked. Game saves and optional diagnostic telemetry logs are not part of the release archives.
