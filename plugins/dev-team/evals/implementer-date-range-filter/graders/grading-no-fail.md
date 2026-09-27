---
type: regex
pattern: '^FAIL'
flags: m
match: not_contains
target: { source: file, path: grading-output.txt }
---
