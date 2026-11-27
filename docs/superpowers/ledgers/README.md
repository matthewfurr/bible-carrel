# Build ledgers

Each project built with subagents keeps a ledger while it is built: every ruling made on Matt's behalf (with what it costs if wrong), every small finding put off and where it went, what was seen live and by whom, and the order things happened in. During the build it lives in the git-ignored workspace `.superpowers/sdd/<plan>/progress.md`, beside task briefs, task reports, reviews and diff packages.

At the end of a project, its documents step copies the ledger here, under the milestone's folder, with the plan's name. Nothing else from the workspace is kept: the briefs are copies of the plan, the diff packages are copies of git, and what mattered in the task reports went into the ledger and the spec's "As built" section.

A ledger still names its old workspace files (`task-3-report.md`, `review-….diff`, `rehearsal.md` and the like). Those were not kept; the commits a ledger names are in git.

- `milestone-10/`: the six projects of milestone 10, copied 2026-11-20 when its worktree was removed.
- `milestone-11/`: the five projects of milestone 11, each copied at its project's end (2026-11-23 and 24); its README gives each ledger's commits.
