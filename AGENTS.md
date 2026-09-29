# Project Rules

This file documents the working rules for this project. Follow them on every change.

## Always after a completed change

1. Run `flutter analyze` — must be clean.
2. Run `flutter test` — all tests must pass.
3. Bump the version in `pubspec.yaml` (patch bump for UI/fixes: `+1`).
4. Commit and push to `origin/main` with a short, descriptive message.

Do not skip the version bump or the push. When a change is done, commit it.

## Conventions

- Respond informally (Hinglish ok) when asked in that style.
- Verify with `flutter analyze && flutter test` before reporting done.