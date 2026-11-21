# Reviewer baseline

Shared rules for the five review gates (`pr-reviewer`, `code-health-reviewer`,
`oss-readiness-reviewer`, `security-reviewer`, `readme-reviewer`). Each gate's agent file tells you
to read this first; it is binding unless the agent file or a project override contradicts it.

## Reviewer probe

Read and run the head in a reviewer probe (the process file's Reviewer probe operation); a reviewer
removes only what it created, and removes it and finishes every tool call before writing the
verdict, which is the last text it emits. Use the probe as given: never clone into it or check out
another revision inside it, and never run a checkout or switch in the live checkout. A guarded
command that a probe shows without running it is spelled as a word no lookup resolves (`git_`,
`GIT_CMD`), never as a case variant such as `GIT`: a case-insensitive filesystem runs the real
binary, and the merge gate matches the lowercase word only.

## Diffing a PR whose base has moved

When the PR's base has moved since the branch was cut (the process file's Merge state operation
reports it behind), diff with its Diff operation or the three-dot form
`git diff origin/<base>...HEAD`, never two-dot `origin/<base>..HEAD`: the two-dot form attributes
every commit merged to the base after the branch point to the PR as if it reverted them, and a
finding built on that is void. The same applies between review rounds: compute "new since last
round" as the difference between each round's own three-dot PR diff, never as
`git diff <old-head> <new-head>`, which attributes base commits picked up by a rebase to the PR.

## Tokens you cannot resolve

Before calling a comment token a session artifact, check `agent-baseline.md` and the sibling gates'
skill files: the `# ponytail:` marker is the harness's own convention for a deliberate
simplification, and the code-health gate requires it.

## Findings that ask for added code

A finding whose fix is to add a guard, a validation, a fallback, a defensive copy or a test for an
input blocks only with a reproducer; the rule covers these kinds of added code and no others. The
reproducer is the input reaching that code through the project's public interface, shown as a
failing test, a command with its output, or the calling lines from that interface to the code. It
shows that the input can arrive, not that the code mishandles it. For the security gate it is the
path to the code from where an input an untrusted party controls enters the repository, cited line
by line; a working exploit is not required, and a finding with that path blocks as every finding
does.

When you cannot show a reproducer, list the item under the `UNREPRODUCED` heading of your output
format, after your findings. An item there is not a finding: it is not counted in `FINDINGS` and
does not change the verdict.

The rule leaves alone this closed list, and each still blocks with no reproducer:

- wrong behaviour the diff shows;
- a false statement in documentation or the change body;
- a failed acceptance criterion of the ticket, a test the ticket names included;
- a request to remove or shorten;
- a style or register finding.

## What a probe never does

A probe never runs a script whose default target is a shared resource (the owner's development
database) without overriding the target, never mutates a fallback so it points at that default and
then runs it, never pipes a live command through `head` or `tail`, never stops a server by command
pattern rather than by the pid it recorded at start, and never edits system or user configuration to
make a check pass; a check the machine cannot run is reported as an environment limit and verified
another way.
