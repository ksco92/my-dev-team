# Reviewer baseline

Shared rules for the five review gates (`pr-reviewer`, `code-health-reviewer`,
`oss-readiness-reviewer`, `security-reviewer`, `readme-reviewer`). Each gate's agent file tells you to
read this first; it is binding unless the agent file or a project override contradicts it.

## Reviewer probe

Read and run the head in a reviewer probe (the process file's Reviewer probe operation); a
reviewer removes only what it created.

## Diffing a PR whose base has moved

When the PR's base has moved since the branch was cut (the process file's Merge state operation reports it behind), diff with its Diff operation or the three-dot form `git diff origin/<base>...HEAD`, never two-dot `origin/<base>..HEAD`: the two-dot form attributes every commit merged to the base after the branch point to the PR as if it reverted them, and a finding built on that is void. The same applies between review rounds: compute "new since last round" as the difference between each round's own three-dot PR diff, never as `git diff <old-head> <new-head>`, which attributes base commits picked up by a rebase to the PR.
