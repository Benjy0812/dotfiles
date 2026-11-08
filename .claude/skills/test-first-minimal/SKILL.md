---
name: test-first-minimal
description: Test-first, minimal code. Writes one failing test per behavior, then the smallest code that makes it pass, then checks a mutation. Use when asked to "tdd", "test first", "red green", "write a failing test", or to implement a behavior or spec with tests. Arg: optional spec file path; otherwise behaviors come from the chat.
---

# TDD

One behavior at a time: failing test, smallest code, mutation proof. Ponytail principles apply.

- Behaviors come from the chat or a spec file path argument (one per bullet). The spec names the target file. Spec non-goals are not implemented; report them as skipped.
- Never edit or delete old tests; the only old line you may touch is the summary trailer count. New test file only if asked.
- Never `git commit`, `push`, `add`, `stash` or `checkout` unless the user's current message says so. Undo your own edits with an exact reverse Edit.

## Setup
1. List the behaviors back with the target file.
2. Pick the runner from the target path:
   - `profiles/**/*.lua` -> `for f in <dir>/test_*.lua; do lua "$f" || echo "EXIT $?"; done`
   - `dotfiles.bash` -> `./tests.bash`
   - anything else -> stop and ask.
3. Run the suite as a baseline. Red -> stop.

## Per behavior
1. Add ONE test immediately before the test file's summary/exit trailer (code after it never counts).
   - Lua: a `check(...)` line; bump the count in the final `print`.
   - Bash: a `check "<name>" <command...>` line (passes when the command succeeds).
2. Run it and confirm it FAILS for the right reason (an assertion, not a syntax/load error). Lua `check()` prints only failures: look for a `FAIL:` line naming it. Bash: `./tests.bash 2>&1 | grep -F "<name>"`.
3. If it passes before any code: flag `PASSED PRE-IMPLEMENTATION`, write no code, ask the user.
4. Write the smallest code in the target file until the test passes.
5. Run the full suite. An old test breaks -> stop and ask.
6. Mutation check: break the new code (invert a condition or return a constant), confirm the NEW test fails, restore with the exact reverse Edit, confirm green.

## Stop and report
3 failed attempts on a behavior (show the last failure), an old test fails, baseline red, spec ambiguous, mutation survives (strengthen the NEW test only, retry), unknown runner.

## Report
| behavior | test | code (file:lines) | red Y/N | mutation Y/N |
|---|---|---|---|---|
Then the suite result, flags, and `skipped: <non-goals>`.
