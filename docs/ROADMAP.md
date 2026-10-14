# Gully Dash: India Rush — Roadmap

## Product goal

Build a small, polished, portrait-mode Android arcade game that can be played offline, with a short repeatable run and Indian auto-rickshaw identity. Avoid unnecessary backend maintenance until a real product feature needs it.

## Milestone 1 — Repository and playable prototype

- [x] Godot 4 project and main scene
- [x] Portrait logical viewport and Android touch input path
- [x] Three-lane road and procedural auto-rickshaw/player
- [x] Smooth lane switching with edge guards and a separate player controller
- [x] Desktop keyboard path for development
- [x] Controller smoke tests for lane bounds, signals and reset behavior
- [ ] Run in the Godot editor and verify visuals manually
- [ ] Install and test the debug APK on a physical Android phone

**Status:** implementation is in place. Device/touch verification is still a required check.

## Milestone 2 — Core gameplay

- [x] Traffic spawning with cars and buses
- [x] Collision, one-hit shield behavior and game-over state
- [x] Score, distance, gradually increasing world speed and restart
- [x] Pause/resume and Android back handling
- [x] Main-menu/paused/game-over state transitions covered by integration smoke tests
- [ ] Confirm sustained gameplay and performance on a real device

## Milestone 3 — Retention and local progression

- [x] Chai coins and 2x coin multiplier
- [x] Passenger pickup with temporary 2x score bonus and risk/reward placement
- [x] Shield pickup
- [x] Best score, wallet, lifetime stats, completed missions and skin selection stored locally
- [x] Exact-once end-run guard at the game coordinator
- [x] Versioned save config, temp-file commit and known-good backup recovery path
- [x] Automated persistence/recovery smoke-test script
- [ ] Manually inspect save behavior through app restart/update on-device

## Milestone 4 — Indian identity and UI polish

- [x] Procedural Indian road-side palette and traffic variety
- [x] Main menu, garage, challenges, settings, pause, exit-confirm and game-over views
- [x] Three unlockable auto palettes (classic, blue, pink)
- [x] Persistent sound/haptics/reduced-motion settings
- [x] Lightweight runtime-generated sound effects; no borrowed music/audio files
- [x] Layout and touch hit areas defined against the portrait logical viewport
- [ ] Replace placeholder drawings/audio with original high-quality art/audio
- [ ] Check clipping, input reachability and readability on multiple physical screen sizes

## Milestone 5 — Reproducible Android debug build

- [x] Pin Godot 4.7.2 stable and matching export templates
- [x] Dockerfile pins JDK 17, Android command-line tools revision, platform 36, build tools, NDK and CMake
- [x] Android debug export preset with a stable package identifier and 64-bit ARM target
- [x] Headless build script imports the project, runs smoke tests and checks the APK output
- [x] GitHub Actions workflow to build the container and publish a downloadable debug APK artifact
- [x] Signing material stays outside the repo; no release keystore or secrets are checked in
- [ ] Confirm the validation workflow passes on GitHub
- [ ] Confirm the Docker Android build workflow succeeds and artifact installs on a phone

**Exit criterion:** a clean checkout can generate a repeatable debug APK. The project has the pipeline committed; the criterion is fully verified only after the workflow and on-device installation succeed.

## Milestone 6 — QA, privacy and ads

- [ ] Low-end Android performance and long-session testing
- [ ] Background/resume, airplane-mode, memory and crash testing
- [ ] AdMob integration after gameplay stability; use test ad units during development
- [ ] Privacy policy and accurate Play Console Data safety/ads declarations
- [ ] Keep ad failures from blocking the core offline game

## Milestone 7 — Play Store release

- [ ] Original app icon, screenshots and store listing
- [ ] Release keystore and signed Android App Bundle (.aab)
- [ ] Internal/closed testing, tester feedback and production-access requirements
- [ ] Verify current Play target-API and policy requirements before submission
- [ ] Production review and staged release

## Initial non-goals

- No login, multiplayer, online leaderboard or custom backend in the first version.
- No paid user acquisition before organic interest and retention are measured.
- No copyrighted movie/game characters, logos, voice lines or music without permission.
- No release keystore, password, API key or account credential in the repository.
