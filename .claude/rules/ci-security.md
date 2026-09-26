Every workflow declares `permissions: contents: read` at workflow level and triggers only on `pull_request` and `push`, never `pull_request_target`.
Third-party tools installed in CI are pinned to an exact version.
