# HTTP layer and GitHub features

Design of record for the move off shell-driven curl, and for the feature set
built on top of it.

Date: 2026-08-25

## Problem

Agitate talked to GitHub by concatenating a curl command into a single string
and handing it to `vim.fn.systemlist`, which runs it through a shell. Three
consequences:

- The request body needed hand written quoting. A missing quote produced an
  invalid body with no diagnostic, which is exactly what happened in `f212921`
  and left repository creation broken.
- The status code was discarded, so every failure was inferred from the body.
  A response that was not JSON produced a decode error rather than a report.
- Every call blocked the editor for the duration of the round trip.

An attempt to replace it with luasocket (`socket.http`) was abandoned:
`socket.http` cannot do HTTPS, and luasocket, luasec and cjson are not shipped
with Neovim, so the plugin would have gained three install time dependencies.

## Decisions

| # | Decision | Rationale |
| --- | --- | --- |
| 1 | `vim.system` with callbacks | No shell, no quoting hazard, no editor blocking. Neovim 0.10 and up. |
| 2 | Token via `curl --config -` on stdin | Argv is world readable through `/proc/<pid>/cmdline` while the request runs. |
| 3 | Breaking changes allowed | Pre-1.0. History already uses `refactor!`. |
| 4 | `vim.notify` with levels | `nvim_err_writeln` is deprecated as of 0.11, and notify respects the user's notification plugin. |
| 5 | `busted --lua=nlua` | Specs run inside a real Neovim and use the genuine `vim.*` API. No runtime dependency. |
| 6 | CI matrix `v0.10.0`, `stable`, `nightly` | 0.10 is the `vim.system` floor. The matrix catches drift against it. |
| 7 | Scratch buffer for issue and PR bodies | The only sane multiline input. Matches `git commit` and fugitive muscle memory. |
| 8 | Custom scratch buffer for lists | Full control over rendering and per line actions. |
| 9 | `vim.ui.select` for template pickers | A one shot choice, not a browsable list. Picks up the user's ui-select plugin without a dependency. |
| 10 | Projects deferred | Classic Projects REST is sunset; V2 is GraphQL only and needs the `project` scope. |
| 11 | `repo.init.remote_protocol`, default https | SSH users otherwise fix the remote by hand after every `Init`. |

## Architecture

```
api/       user command registration only
core/      orchestration, callback driven
service/   http.lua  (transport)
           github.lua (one function per endpoint, built on http)
ui/        buffer.lua (scratch editor), list.lua (result buffers)
util/      shell, url and string helpers
types/     LuaLS annotations only, no runtime
```

Dependency direction is one way: `api -> core -> service -> util`. Nothing in
`service` knows about commands, and nothing in `util` knows about GitHub.

### `service.http`

One entry point:

```lua
http.request({ url, method, token, body }, function(ok, result) end)
```

Contract:

- The callback fires exactly once, always through `vim.schedule`. `vim.system`
  completes in a fast event context where most of `vim.api` is unavailable, so
  scheduling inside the client means no caller has to remember it.
- `ok == false` yields an `AgitateError`. This covers curl failing to start,
  curl exiting non-zero, and a response with no readable status.
- `ok == true` yields `{ status, body, raw }`. A non-2xx status is *not* a
  transport failure; interpreting the status is the caller's job.
- A body that does not parse as JSON is not an error either. `body` is nil and
  `raw` carries the response, which is what makes a useful message possible
  when a proxy returns HTML.
- `--fail` is deliberately unused: GitHub puts the useful explanation in the
  body of a 4xx and `--fail` discards it.
- The status code is appended to stdout on its own trailing line via
  `--write-out`, so one stream carries both body and status.
- The API version is pinned rather than following the current default.

### Token handling

`vim.system` takes an argument vector and never involves a shell, so nothing
needs quoting. Argv is still readable through `/proc/<pid>/cmdline` by any
process running as the same user for as long as the request is open. The token
is therefore written to curl's stdin as a config entry, and escaped so that a
token containing a quote or backslash cannot terminate the entry.

The request body is *not* secret and stays in argv, where it needs no escaping
at all.

## Naming

Two module kinds, two conventions. Worth stating, because review has queried
the mix more than once and neither half explains the other.

**Command modules** (`core/*`) expose PascalCase entry points, one per user
command: `Create`, `Init`, `Delete`, `Merge`. Anything else they export is an
implementation detail reachable from a spec and carries an underscore:
`_plan_merge`, `_plan_delete`, `_comment`.

**Library modules** (`service/*`, `ui/*`, `util`) expose snake_case functions
as their ordinary public API: `describe_failure`, `origin_repository`,
`render`. These are called by other modules, never by users, so there is no
command surface to distinguish. An underscore still means test seam, as in
`http._build_argv`.

Adding a function: if a user invokes it, PascalCase in `core`. If only Agitate
calls it, snake_case in a library module. If only a spec calls it, prefix it.

## Error handling

One shape everywhere. `AgitateError` is `{ message = string }`.
`agitate_error.throw` accepts a string, an `AgitateError`, or a list of either,
resolves it through `describe`, and notifies at ERROR level. `describe` returns
nil when a value carries no message, and `throw` substitutes the unhandled
message itself rather than calling back into `throw`, which is what prevents
the recursion the original had.

GitHub failures are rendered by `github.describe_failure`, which surfaces both
the top level `message` and each entry of the `errors` array, because the
second layer carries the actionable part.

## Testing

`busted` driven through `nlua`, so specs execute inside a real Neovim.

Three levels:

- Pure functions tested directly: `parse_args`, `util`, `error`.
- Request construction tested by inspecting argv and the stdin config, which is
  where the token exposure and JSON encoding guarantees are pinned.
- The transport exercised end to end against `file://` URLs, so the real curl
  process runs without touching the network or rate limits.
- `service.github` tested by stubbing `http.request` and driving the real
  captured GitHub payloads in `tests/fixtures`.

CI additionally bounds every job with `timeout-minutes`, because driving busted
through nlua occasionally leaves the Neovim process alive after the suite has
reported.

## Deferred

- **Projects.** Classic Projects REST is sunset. Projects V2 is GraphQL only,
  needs a second API paradigm alongside REST, and requires a token carrying the
  `project` scope.
- **Removing `util.json_lr_trim`.** It exists only to clean noise out of
  scraped shell output and has no caller now. Left in place as a separate
  decision.
