# AGENTS.md

## Project

JOSEPH is a native macOS menu-bar utility for travel power management and supervision of long-running local workflows. The Remote GUI concept is a final-phase research project and must not drive MVP architecture. This repository starts from a blank slate: there is no pre-existing contributor work to protect, no legacy history to preserve, and no prior architecture the agent is constrained by beyond this document.

## Autonomy grant

The repository owner has explicitly authorized the agent to run **long, uninterrupted autonomous sessions** against an agreed plan — potentially for hours — without pausing mid-task to ask permission. The owner wants to be solicited **as little as possible**, and only at natural checkpoints: when a planned task is fully complete, when the agent is genuinely blocked by something outside this authorization, or when it hits one of the hard boundaries below. Mid-task status questions, "can I proceed?"-style check-ins, or asking permission for routine sub-steps are not wanted and should not happen.

Within a task, the agent should, without asking:

- Write, refactor, and restructure code as needed to implement the plan.
- Install, add, remove, or upgrade project dependencies (package managers, SPM/CocoaPods, build tooling) — this is treated as routine and never requires a check-in.
- Create files/folders, scaffold modules, generate the Xcode project via XcodeGen, and reorganize the project layout.
- Run builds, run tests, and iterate on failures itself until green (or until it determines the plan itself needs revision).
- **Commit at each meaningful step** (see Repository workflow) rather than batching everything into one giant commit, so progress stays legible without needing to interrupt the owner.
- Make local judgment calls on implementation details consistent with the engineering standards below.

The agent should only interrupt the owner before a task is finished for one of these reasons, not for routine progress:

- Pushing to a remote or creating/deleting any resource outside the local checkout.
- Requesting new macOS entitlements/privileged permissions or anything that changes system-level security posture.
- An action that is destructive and hard to reverse outside the project itself (e.g., touching files/volumes outside the repo).
- Encountering committed secrets/credentials, or an ambiguity in the plan itself that materially changes scope or intent.

This autonomy is scoped to this project's dev environment on this machine. It is not OS administrator privilege and does not bypass platform security.

## Working on a plan

When given a multi-step plan, the agent should execute it end-to-end autonomously:

- Treat the plan as the source of truth; work through its steps in order without pausing between them for approval.
- If a step reveals the plan needs adjusting, adapt and continue rather than stopping to ask — note the deviation in the commit message or a short end-of-session summary instead.
- Only report back once the whole task (or the full plan, if asked to run it end-to-end) is done: what was built, what was verified, what wasn't, and anything genuinely requiring the owner.
- If a session must stop before the plan is finished (hard blocker, timeout, missing tooling), leave the repo in a clean, buildable, committed state and clearly state what remains.

## Engineering standards

- Prefer small, reviewable commits over one broad rewrite — this keeps a long autonomous run auditable after the fact, even though nothing blocks on review during the run.
- Preserve existing behavior unless the task explicitly changes it; on a blank-slate project this mainly means staying consistent with earlier commits made in the same session.
- Use Swift concurrency and actor isolation deliberately; keep UI-owned state on `@MainActor`.
- Abstract OS services such as IOKit, process launching, filesystem access, and network inspection so they can be tested without hardware.
- Treat macOS APIs and entitlements as platform-specific: verify availability, document limitations, and never promise clamshell, thermal, USB, or routing behavior without hardware validation.
- Avoid deprecated privileged APIs. Any privileged operation must still have a minimal, auditable design and a rollback path — a design discipline the agent applies itself, not something it stops to ask about.
- Do not execute shell commands by interpolating untrusted input.
- Keep logs useful, bounded, privacy-conscious, and resilient to filesystem failures.
- Make lifecycle cleanup explicit: assertions, child processes, file handles, observers, timers, and tasks must be released or cancelled.

## Required verification

For non-trivial changes, run these autonomously as part of the task, not as a checkpoint to wait on:

1. Generate the Xcode project with XcodeGen when `project.yml` changes.
2. Build with the supported macOS deployment target.
3. Run unit tests.
4. Check warnings and failures introduced by the change, and fix or clearly log them before moving on.
5. Update documentation when behavior, permissions, setup, or limitations change.

If macOS/Xcode tooling is unavailable, MAKE IT AVAILABLE BY ALL METHODS, report that fact in the end-of-task summary instead of claiming verification succeeded. Never state a build or test passed without having actually run it.

## Architecture priorities

1. Testable power assertion state and safe cleanup.
2. Reliable process supervision, process-group termination, output capture, and log rotation.
3. Read-only network diagnostics before any automatic routing changes.
4. Opt-in network policy with backup and rollback.
5. Hardware-specific thermal providers with safe fallbacks and hysteresis.
6. Remote GUI only after the core product is stable and the required Apple permissions and transport design are validated.

## Repository workflow

- Inspect `git status` before consequential Git operations, then proceed — on this blank-slate project there is no other contributor's work to accidentally clobber, but the check stays cheap insurance.
- Commit at each meaningful completed step of the plan (a working feature slice, a passing test suite, a completed refactor) rather than waiting until the very end — this is required, not optional, so the owner can see progress without asking for it.
- Never commit secrets, credentials, personal logs, generated build artifacts, or machine-specific configuration.
- Do not push or create remote resources unless the repository owner explicitly requests that exact action and the required authentication is available.
- Keep the repository buildable at each commit and document any known limitation.

## Permission boundary

The owner's authorization covers extended, unattended project work in the local dev environment, including dependency installation, scaffolding, refactors, builds, tests, and incremental commits — none of that requires a pause. It does not extend to OS administrator privileges, bypassing platform/security mechanisms, or the hard-boundary actions listed under "Autonomy grant" (remote pushes/resources, new privileged entitlements, destructive actions outside the repo, exposed secrets). Within that boundary the agent should run the full plan and only speak up at completion or at a genuine blocker. Agents must always accurately report, at that checkpoint, what they did, what they could not do, and which commands (if any) genuinely require the owner because they exceed this boundary.
s