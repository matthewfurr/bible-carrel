# How every implementer on this plan works

Work from `/Users/matt/Code/reading-through-scripture/.claude/worktrees/milestone-11-ui-improvements`. Never `cd` elsewhere and never touch files outside it.

## Before you begin

If anything in your brief is unclear (requirements, approach, dependencies), ask now by replying NEEDS_CONTEXT with the specifics. Do not guess.

## Your job

1. Implement exactly what the brief specifies, test first, in the brief's own steps: write the failing tests, run them and see them fail for the expected reason, implement, run and see them pass.
2. Verify the implementation works. Where the brief has a step that looks at the UI, do it and open every picture you take.
3. Commit your work as the brief's commit steps say. Git rules are in `global-constraints.md`: `/usr/bin/git`, one git command per Bash call, and the attribution line that file gives at the end of each commit message.
4. Self-review, then report.

While iterating, run the focused test for what you are changing (`--filter` for the package suite, `-only-testing:ScriptureUITests/<Suite>` for the iOS suite). Run the full package suite and the full iOS `ScriptureUITests` once before your last commit. Run builds and test runs one after another, never at once.

A known flake: `ReaderBenchmarkTests.scrollingWhileTheThumbRevealsKeepsTheFrameCost` (and other timing benchmarks) can fail under full-suite load; rerun it alone before treating it as yours.

## The owner is using this Mac

Any keystroke, click or scroll you send goes to whatever is in front, which may be the owner's browser or editor, not the Debug app. Twice already an agent's event landed in another app. Before every keystroke, click or scroll: confirm the Mac Debug app is the frontmost app and that the point you are about to click or scroll is inside its window; if it is not, do not send the event. Never move, resize or re-space the owner's windows to get at the app. Prefer the keyboard inside the app (Page Down, the arrows) to scroll-wheel events at a screen position. If the app cannot be brought to the front without disturbing his work, skip the by-eye step and say so in your report.

## You do not dispatch subagents

Do all of the task yourself. Never spawn a subagent to implement part of it or to review it. Self-review means reading your own diff; a separate reviewer is dispatched after you report.

## Code organisation

- Follow the file structure the brief defines.
- If a file you create grows beyond the brief's intent, stop and report DONE_WITH_CONCERNS; do not split files on your own.
- Follow the codebase's existing patterns; do not restructure things outside your task.

## When you are in over your head

It is always fine to stop. Reply BLOCKED or NEEDS_CONTEXT when the task needs an architectural decision with several valid approaches, when you cannot find clarity in the code, or when you are unsure your approach is correct. Say what you are stuck on, what you tried and what help you need. Never silently produce work you are unsure about.

## Before reporting: self-review

- Completeness: everything in the brief, and its edge cases.
- Quality: clear names, clean code.
- Discipline: nothing beyond the brief; existing patterns followed.
- Testing: tests verify behaviour, not mocks; the test output is pristine (a new warning is a defect).

Fix what you find before reporting.

## After review findings

If the task review finds issues you will be resumed with them. Fix them, re-run the covering tests, and append a fix report to your report file: what changed, the tests run, the command, the output. Then reply with the same short status as before.

## The report

Write the full report to the report file your dispatch names:

- what you implemented (or attempted, if blocked);
- what you tested and the results, with the test counts of both suites;
- TDD evidence: RED (command, the relevant failing output, why it was expected) and GREEN (command, the relevant passing output);
- what you looked at by eye and what you could not see;
- files changed;
- every decision you made that the brief did not settle, each marked **(call)**;
- self-review findings and concerns.

Then reply with ONLY this, in under 15 lines:

- **Status:** DONE | DONE_WITH_CONCERNS | BLOCKED | NEEDS_CONTEXT
- commits created (short SHA and subject);
- a one-line test summary;
- your concerns, if any;
- the report file path.

If BLOCKED or NEEDS_CONTEXT, put the specifics in the reply itself.
