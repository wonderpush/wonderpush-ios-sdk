# sdk-sync conformance vectors

Language-neutral `{input → expected}` fixtures for the **pure-logic** parts of the sdk-sync
channel. Every SDK (JS, iOS, Android) ships a thin harness that runs these exact fixtures and must
reproduce the exact outputs. This turns cross-SDK behavioural consistency into a **mechanical CI
gate** rather than a review/discipline problem.

These vectors are the executable companion to [`../algorithm.md`](../algorithm.md): the prose spec
says what should happen; the vectors pin the exact values.

## Provenance

Generated from the **JS reference SDK** (`wonderpush-javascript-sdk`), which is the most-tested
implementation. The generator is `src/wonderpush/sync-conformance-gen.test.ts` in that repo. Each
file's `expected` is literally what the reference function returned for that `input`, so the JS impl
is conformant by construction; the other SDKs are validated against it.

Regenerate (from the JS repo) after any change to the reference pure-logic:

```sh
GEN_CONFORMANCE=1 npx jest sync-conformance-gen
# optional: CONFORMANCE_OUT=/abs/path to write elsewhere
```

A non-empty `git diff` here after regeneration means the reference behaviour changed — update the
spec + all SDK ports to match, in lockstep.

## Files

`index.json` lists every file and case count. Each `*.vectors.json` covers one function:

| file | function | what it locks |
|---|---|---|
| `compare-version-id.vectors.json` | `compareVersionId(a,b)` | the null/int64/string total order |
| `accepts-response.vectors.json` | `acceptsResponse(response,state)` | the acceptance check (monotonic + empty-reset) |
| `process-source-block.vectors.json` | `processSourceBlock(block,serverTime,state,mode)` | the core decision: apply/clear/fetch + next state |
| `classify-response.vectors.json` | `classifyResponse(path,method)` | opportunistic vs explicit vs none routing |
| `compute-backoff-sleep.vectors.json` | `computeBackoffSleep(attemptCount,rand,knobs)` | the backoff formula |
| `should-debounce-weak-signal.vectors.json` | `shouldDebounceWeakSignal(now,last,debounceMs)` | weak-signal debounce window |
| `should-rate-limit-source.vectors.json` | `shouldRateLimitSource(now,last,minIntervalMs)` | per-source fetch floor |
| `merge-knobs.vectors.json` | `mergeKnobs(defaults,remoteConfig)` | remote-config override merge |
| `is-state-stale.vectors.json` | `isStateStale(state,knobs,now)` | max-age forcing predicate |
| `contact-store.vectors.json` | `applyContactData / applyContactDelta / clearContact` | single-object replace/patch/wipe (uses JSON merge w/ null-removes) |
| `default-knobs.json` | `DEFAULT_KNOBS` | the canonical default knob values |

## Encoding conventions

- **`Infinity` / `-Infinity` / `NaN`** are emitted as the JSON **strings** `"Infinity"`, `"-Infinity"`,
  `"NaN"` (JSON has no literal for them). The age caps default to `"Infinity"` (= no forcing). Each
  harness must map these strings back to its language's infinity/NaN before calling the function.
- **`null`** is the *null-missing* sentinel for `versionId`/`knownVersionId` and the absence of an
  optional field. It is a real value here, distinct from `"Infinity"`.
- **State & decision objects** (`process-source-block`, `is-state-stale`) carry **full**
  `SyncSourceState` structs in both `input.state` and `expected.newState`; compare by **deep
  equality**. A decision omits fields that weren't set (e.g. no `triggerFetch` key ⇒ no fetch).
- **`computeBackoffSleep`** outputs an IEEE-754 **double**; compare within a small relative epsilon
  (e.g. `1e-6`), not bit-exact, to absorb formatting differences.
- All timestamps are integer ms since epoch; all `version` values are int64-range integers.

## How a port consumes these

1. **Vendor** these JSON files into the SDK repo (checked-in copy, or a git submodule of this repo),
   pinned to a spec revision.
2. Add a harness test that, for each file, loads `cases`, calls the corresponding port function with
   `input`, and asserts the result deep-equals `expected` (float epsilon for backoff; infinity-string
   mapping for knobs/age-caps).
3. Wire it into the SDK's normal test run so drift fails CI.

What these vectors do **not** cover: the platform **glue** (persistent storage, request-param
injection, the response hook, fetch scheduling, locking). That is inherently I/O and platform-
specific — covered by `algorithm.md` + per-SDK integration tests, not by these fixtures.
