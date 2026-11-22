An eval grader judges one item (a line, a fix, a row) and never a count of findings. An eval case
meant to show that a rule suppresses a finding is run on the tree without the rule, with only the
case and its fixture copied in, and is kept only if it fails there.
