# tpm server-probe rules

Binding rules for what a gate probes when a PR starts a server, a child process or a JVM: its
environment, its listeners, its configuration and its class path. Read with `review-probes.md`
before the first gate on such a PR.

- A gate that may start a server holding cloud credentials launches it from a scrubbed environment:
  every credential-chain variable unset (static keys and session token, profile, web identity,
  container credentials), instance metadata disabled, placeholder static keys, the config and
  credentials file variables pointed at scratch files, and a dead SDK endpoint. Every client the run
  builds must be refused by that endpoint; one refused first call proves one client.
- A guard added to one middleware is proven on the real server with the raw bad request sent through
  the whole chain; a sibling registered earlier can parse the same input unguarded.
- A startup check moved into a function a dev server re-runs on an in-process restart is proven by
  changing a scratch copy of its backing file, never the owner's own, and restarting in the same
  process; a module-level cache in the dependency keeps the check stale.
- Before trusting a bind address or port set through configuration flags, grep the server's source
  or bytecode for `getenv`, for the configuration-directory variables it reads (`SPARK_CONF_DIR`,
  `HADOOP_CONF_DIR`) and for a second key prefix merged after the one the launcher sets; prove each
  with a harmless override such as `::1` and an `lsof` listing, never `0.0.0.0`.
- When a PR presents a session-scoped setting as a security control on a server clients reach over
  SQL, run `SET <key>=<permissive value>` from a client and retry the blocked statement; a setting a
  client can reset is a default, not a control.
- Prove a server that loads plugins from a class path fixed at JVM start with a real client session
  that exercises the plugin, not with a ready log line or a listening port, and test the first start
  from an empty cache on its own; a jar that joins the class path once the JVM runs is unusable for
  the whole run.
