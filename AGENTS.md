# Repository Instructions

## Read first

- `README.md` for the current product boundary and runnable commands.
- `docs/project-overview.md` for the user problem and observable product behavior.
- `docs/architecture.md` for component responsibilities and runtime boundaries.
- `plan.md` for roadmap status and the active phase contract.
- `checklist.md` for verified evidence, partial work, and external blockers.
- The closest design, contract, migration, and test files for the code being changed.

## Source of truth

- Product intent and safety constraints belong in `docs/project-overview.md`.
- Observable behavior and interfaces belong in code, tests, OpenAPI, and JSON Schema. When they disagree, do not guess: report the conflict and treat execution as blocked until the contract is reconciled.
- Architecture ownership belongs in `docs/architecture.md`.
- Sequence, active scope, and evidence status belong in `plan.md` and `checklist.md`; neither may silently introduce a product requirement.
- A requirement change updates the relevant product/contract source before implementation status.

## Working rules

- Keep changes inside one approved vertical slice and preserve unrelated user changes.
- Do not add dependencies, deployment, secrets, FITRUS assumptions, or physical-device behavior without an explicit contract and approval.
- Keep raw/provider data separate from normalized and derived results.
- Preserve `pilot-0.7.0` safety boundaries: physical execution is `PROHIBITED`, commands are `SIMULATOR_ONLY`, and `realDeviceSendAllowed=false` until the documented promotion gates are met.
- Treat missing supplier definitions, device calibration, real-device ACK behavior, and clinical validation as blockers, not implementation details to infer.
- For behavior changes, establish a failing regression test for the intended reason, make the smallest implementation change, then run focused and repository-wide checks. If the test does not fail for the intended reason, stop and report `BLOCKED`.
- Do not describe a check as passed unless it ran. Use `PASS`, `FAIL`, or `NOT RUN` and include the command or evidence link.

## Verification

Run the checks relevant to the changed area. Run both suites for shared-contract or cross-boundary changes.

```bash
cd backend-api
npm ci
npm run typecheck
npm test -- --reporter=dot
```

```bash
cd mobile-app
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze --no-pub
flutter test --no-pub --reporter compact
flutter build apk --debug --no-pub
```

Device, FITRUS, AWS, accessibility, and clinical checks remain `NOT RUN` unless the required real environment and evidence are available.

## Final report

- Changed files and user-visible behavior.
- Verification commands and actual `PASS`/`FAIL`/`NOT RUN` results.
- Contract or documentation updates.
- Remaining risks, blockers, and assumptions.

