# Research: B1 — trailing-dash checkver versions (`1.4.0-`, `2.0-`, `9-`) — upstream tag facts + proposed regexes

- **Query**: For the 11 B1 apps, what do upstream tags/releases actually look like, and what checkver regex captures the FULL version (or pins to stable) correctly?
- **Scope**: external (GitHub via authenticated `gh api`) + local manifests + scoop core source
- **Date**: 2026-10-01

## TL;DR

All 11 manifests use `"checkver": "github"` (or `{"github": "<url>"}`) **without any regex**. The trailing `-` comes from scoop's built-in default regex, not from anything in our manifests. Nearly every upstream marks its suffixed tags (`-beta`, `-rc`, `-alpha`) as **non-prerelease**, so GitHub's `/releases/latest` happily returns them and scoop's default regex chops the suffix mid-way.

| App | Repo | Latest release (flag) | Plain stable exists? | Recommended checkver | Resulting version |
|---|---|---|---|---|---|
| froggit | thewizardshell/froggit | `v1.4.0-beta` (stable) | No (every tag is `-beta`) | github + regex | `1.4.0-beta` |
| airi | moeru-ai/airi | `v0.12.0-beta.5` (stable) | Older `v0.11.3` only | github + regex | `0.12.0-beta.5` |
| allusion | allusion-app/Allusion | `v1.0.0-rc.10` (stable) | No | github + regex | `1.0.0-rc.10` |
| mykeymap | xianyukang/MyKeymap | `v2.0-beta33` (stable) | No | github + regex | `2.0-beta33` |
| gclone | dogbutcat/gclone | `v1.73.3-mod1.6.2` (stable) | N/A (`-mod` IS their scheme) | github + regex | `1.73.3-mod1.6.2` |
| project-86 | Taliayaya/Project-86 | `v2.0.0-alpha.2` (stable) | No | github + regex ⚠ zero assets | `2.0.0-alpha.2` |
| fx | metrue/fx | `0.9.48-alpha.d91a7a0` (stable) | **Yes** — `0.9.48` | **atom + stable-only regex** | `0.9.48` |
| zoraxy | tobychui/zoraxy | `v3.3.5-rc2` (stable) | **Yes** — `v3.3.4` | **atom + stable-only regex** | `3.3.4` |
| revezone | revezone/revezone | `1.0.0-alpha.18` (stable) | No | github + regex | `1.0.0-alpha.18` |
| wsl-centos-7 | mishamosher/CentOS-WSL | repo latest = `9-stream-20230626` | n/a (need 7.x pin) | **atom + `CentOS (7…)` pin** | `7.9-2211` |
| wsl-centos-8 | mishamosher/CentOS-WSL | repo latest = `9-stream-20230626` | n/a (need 8.x pin) | **atom + `CentOS (8…)` pin** | `8-stream-20230626` |

---

## Root cause (verified against scoop core `bin/checkver.ps1`, master)

Scoop resolves `checkver: "github"` like this (lines ~155–191):

```powershell
if (($json.checkver -eq 'github') -or $json.checkver.github) {
    ...
    $url = $inputGithubUrl.TrimEnd('/')          # from homepage, or checkver.github (full URL accepted)
    if ($url -notlike 'https://api.github.com*') { $url = $url + '/releases/latest' }
    if ($GitHubToken) {                          # excavator ALWAYS has a token
        $url = $url -replace '//(www\.)?github\.com/', '//api.github.com/repos/'
        $wc.Headers.Add('Authorization', "token $GitHubToken")
    }
    if ($url -like 'https://api.github.com*') {
        if (-not $json.checkver.script) { $jsonpath = '$.tag_name' }
        if (-not $regex) { $regex = '(?:v|V)?([\d.-]+)' }        # ← DEFAULT REGEX
    } elseif (-not $regex) {
        $regex = '/releases/tag/(?:v|V)?([\d.-]+)'              # ← HTML-mode default
    }
}
```

- With a token (excavator), scoop hits `api.github.com/repos/{repo}/releases/latest`, pulls `$.tag_name`, then applies the regex to the **bare tag string** (`if ($jsonpath -and $regexp) { $page = $ver; $ver = '' }`).
- The default regex `([\d.-]+)` — character class contains digits, `.`, **and `-`** — greedily eats the dash, then stops at the first letter. Verified reproduction against every real tag below:

| tag_name | default regex captures |
|---|---|
| `v1.4.0-beta` | `1.4.0-` |
| `v0.12.0-beta.5` | `0.12.0-` |
| `v1.0.0-rc.10` | `1.0.0-` |
| `v2.0-beta33` | `2.0-` |
| `v1.73.3-mod1.6.2` | `1.73.3-` |
| `v2.0.0-alpha.2` | `2.0.0-` |
| `0.9.48-alpha.d91a7a0` | `0.9.48-` |
| `v3.3.5-rc2` | `3.3.5-` |
| `1.0.0-alpha.18` | `1.0.0-` |
| `9-stream-20230626` | `9-` |

Matches the excavator failures exactly (`1.4.0-`, `2.0-`, `9-` were named in prd.md; the rest are derived from the same mechanism).

- **Fix mechanism**: a custom `checkver.regex` replaces the default regex. In API mode it is matched against the bare `tag_name`; in no-token HTML mode against the release page HTML (tag string appears there too, so tag-shaped regexes work in both modes).
- `{"github": "https://github.com/owner/repo"}` (full URL) is explicitly accepted by the `githubUrlPattern` — airi/revezone's current form is valid.

Autoupdate note: `$version` carries the FULL captured string including suffix (proof: existing manifests' `$version` URLs resolve to real assets for `1.0.0-rc.10`, `2.0-beta33`, `1.0.0-alpha.18`…). `$preRelease` (e.g. `rc.10`) is also available if a URL ever needs the suffix separately. So suffix-capturing checkver fixes require **no autoupdate template changes** except wsl-centos-8 (asset renamed — see below).

---

## Per-app findings

### 1. froggit (`bucket/froggit.json`, manifest version `1.1.0-beta`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all `prerelease: false`): `v1.4.0-beta`, `v1.3.0-beta`, `v1.2.0-beta`, `v1.1.0-beta`, `v0.5.0-beta`, `v0.4.1-beta` → latest = `v1.4.0-beta`.

- Stable (non-prerelease) release in the plain-semver sense: **none exists** — every release ever is `-beta` (and all are flagged non-prerelease, so `/releases/latest` = `v1.4.0-beta`).
- Assets on `v1.4.0-beta`: `windows-amd64.zip` (+darwin/linux) → autoupdate template `v$version/windows-amd64.zip` works unchanged.

Proposed:

```json
"checkver": {
    "github": "https://github.com/thewizardshell/froggit",
    "regex": "v?([\\d.]+(?:-beta(?:\\.\\d+)?)?)"
}
```

(decodes to `v?([\d.]+(?:-beta(?:\.\d+)?)?)`; captures `1.4.0-beta`; also handles a future `-beta.2` or plain `v1.5.0`. Verified.)

### 2. airi (`bucket/airi.json`, manifest version `0.11.3`)

Current checkver (quoted):

```json
"checkver": {
    "github": "https://github.com/moeru-ai/airi"
}
```

Recent tags: `v0.12.0-beta.5` (**prerelease=false**), `v0.12.0-beta.4` (true), `v0.12.0-beta.3` (true), `v0.12.0-beta.1` (true), `v0.11.3` (false), `v0.11.1` (true) → `/releases/latest` returns `v0.12.0-beta.5` (upstream un-flagged beta.5, making it the "latest stable" in GitHub's model).

- Plain-semver stable exists (`v0.11.3`) but is older than the release GitHub itself promotes as latest. Tracking `/releases/latest` (= upstream's own choice) is the sane behavior; a pure-stable-only regex would freeze the app on `0.11.3` and rely on the fragile atom window (see Caveats).
- Assets on `v0.12.0-beta.5`: `AIRI-0.12.0-beta.5-windows-x64-setup.exe` ✓ matches existing template.

Proposed:

```json
"checkver": {
    "github": "https://github.com/moeru-ai/airi",
    "regex": "v?([\\d.]+(?:-beta(?:\\.\\d+)?)?)"
}
```

→ `0.12.0-beta.5`; also handles future plain `v0.12.0`. Verified.

### 3. allusion (`bucket/allusion.json`, manifest version `1.0.0-rc.10`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all non-prerelease): `v1.0.0-rc.10`, `v1.0.0-rc9`, `v1.0.0-rc8.1`, `v1.0.0-rc8`, `v1.0.0-rc7.3`, `v1.0.0-rc7.2` → latest = `v1.0.0-rc.10`.

- Naming pattern is INCONSISTENT: `-rc7.3`, `-rc9`, then `-rc.10` (dot appeared at rc.10). Regex must handle both `-rcN` and `-rc.N`.
- Plain stable: **none**. Manifest already at latest; asset `AllusionPortable.1.0.0-rc.10.exe` ✓.

Proposed:

```json
"checkver": {
    "github": "https://github.com/allusion-app/Allusion",
    "regex": "v?([\\d.]+(?:-rc\\.?\\d+(?:\\.\\d+)?)?)"
}
```

(decodes to `v?([\d.]+(?:-rc\.?\d+(?:\.\d+)?)?)`; verified against `v1.0.0-rc.10` → `1.0.0-rc.10`, `v1.0.0-rc9` → `1.0.0-rc9`, `v1.0.0-rc7.3` → `1.0.0-rc7.3`, plain `v1.0.0` → `1.0.0`.)

### 4. mykeymap (`bucket/mykeymap.json`, manifest version `2.0-beta33`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all non-prerelease): `v2.0-beta33`, `v2.0-beta32`, `v2.0-beta31`, `v2.0-beta30`, `v2.0-beta29` → latest = `v2.0-beta33`. Pattern is always `-beta<NN>` (no dot).

- Plain stable: **none** (upstream ships beta series as regular releases). Manifest already at latest; asset `MyKeymap-2.0-beta33.7z` ✓.

Proposed:

```json
"checkver": {
    "github": "https://github.com/xianyukang/MyKeymap",
    "regex": "v?([\\d.]+(?:-beta\\d+)?)"
}
```

Verified: `v2.0-beta33` → `2.0-beta33`.

### 5. gclone (`bucket/gclone.json`, manifest version `1.71.0-mod1.6.2`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all non-prerelease): `v1.73.3-mod1.6.2`, `v1.71.0-mod1.6.2`, `v1.69.2-mod1.6.2`, `v1.69.1-mod1.6.2`, `v1.67.0-mod1.6.2`, `v1.67.0-mod1.6.1` → latest = `v1.73.3-mod1.6.2`.

- `-modX.Y.Z` is gclone's permanent versioning scheme (rclone base + mod release); it is NOT a prerelease suffix. A "stable-only" regex is meaningless here — the suffix must be captured.
- Windows assets on `v1.73.3-mod1.6.2` confirmed for all three arches: `gclone-v1.73.3-mod1.6.2-windows-amd64.zip`, `-windows-386.zip`, `-windows-arm64.zip` ✓ templates unchanged. Manifest bumps 1.71.0-mod1.6.2 → 1.73.3-mod1.6.2.

Proposed:

```json
"checkver": {
    "github": "https://github.com/dogbutcat/gclone",
    "regex": "v?([\\d.]+-mod[\\d.]+)"
}
```

Verified: → `1.73.3-mod1.6.2`.

### 6. project-86 (`bucket/project-86.json`, manifest version `1.11.1-alpha`) ⚠

Current checkver (quoted): `"checkver": "github"`

Recent tags: `v2.0.0-alpha.2` (**prerelease=false**), `v2.0.0-alpha.1` (true), `v1.11.1-alpha` (false), `v1.10.3-alpha` (false), `v1.10.2-alpha` (true) → latest = `v2.0.0-alpha.2`.

- Plain stable: **none** (all releases are `-alpha[.N]`, and bare `-alpha` also occurs — `v1.11.1-alpha`).
- **⚠ CRITICAL CAVEAT: `v2.0.0-alpha.2` has ZERO release assets** (`gh api repos/Taliayaya/Project-86/releases/tags/v2.0.0-alpha.2` → `assets: []`; the older `v1.11.1-alpha` has 1 asset = the zip our manifest uses). Fixing the regex makes checkver return `2.0.0-alpha.2` ≠ manifest `1.11.1-alpha`, so excavator will attempt autoupdate and **fail with an asset-404** — the app moves from the B1 list to the B2 (asset) list. Options for main agent: accept the move (regex is still correct), or handle together with B2 round.

Proposed:

```json
"checkver": {
    "github": "https://github.com/Taliayaya/Project-86",
    "regex": "v?([\\d.]+(?:-alpha(?:\\.\\d+)?)?)"
}
```

Verified: `v2.0.0-alpha.2` → `2.0.0-alpha.2`, `v1.11.1-alpha` → `1.11.1-alpha`.

### 7. fx (`bucket/fx.json`, manifest version `0.9.48`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all non-prerelease): `0.9.48-alpha.d91a7a0`, `0.9.48-alpha.bdece85`, `0.9.48`, `0.9.47-alpha.c850755`, `0.9.47-alpha.5f554b4` → latest = `0.9.48-alpha.d91a7a0` (commit-suffixed alphas flagged as stable releases; no `v` prefix).

- **Plain stable exists: `0.9.48`** — but it is OLDER than the two alphas above it. Per the task rule (stable exists → prefer stable-only), recommend the atom-feed approach so checkver stays on `0.9.48`:

```json
"checkver": {
    "url": "https://github.com/metrue/fx/releases.atom",
    "regex": "<title[^>]*>(\\d+(?:\\.\\d+)+)</title>"
}
```

Feed titles (newest first, verified live): `0.9.48-alpha.d1a7a0…`, `0.9.48`, `0.9.48-alpha.bdece85`, … — the `</title>` right-anchor rejects alpha titles; first match = `0.9.48` = current manifest version → checkver immediately GREEN, no bump. Verified.

- Alternative (if tracking upstream's alphas is preferred instead): `{"github": "https://github.com/metrue/fx", "regex": "(\\d[\\d.]+(?:-alpha\\.[0-9a-f]+)?)"}` → version `0.9.48-alpha.d91a7a0`; asset `fx_0.9.48-alpha.d91a7a0_windows_64-bit.tar.gz` exists ✓ (the mandatory-suffix core `(\d[\d.]+-alpha\.[0-9a-f]+)` was verified literally; optional-suffix variant follows the same verified construct).
- Fragility note: atom feeds expose only ~10 newest entries. If >10 alphas ship before the next stable, the `0.9.48` title drops out of the feed and checkver breaks again. Upstream currently has 2 alphas above the stable entry, so there is headroom, but this is a time bomb — see Caveats.

### 8. zoraxy (`bucket/zoraxy.json`, manifest version `3.3.4`)

Current checkver (quoted): `"checkver": "github"`

Recent tags (all non-prerelease): `v3.3.5-rc2`, `v3.3.5-rc1`, `v3.3.4`, `v3.3.4-rc3`, `v3.3.4-rc2`, `v3.3.4-rc1`, `v3.3.3`, … → latest = `v3.3.5-rc2`. Upstream habitually does NOT flag rcs as prereleases, so `/releases/latest` sits on an rc.

- **Plain stable exists: `v3.3.4`**. zoraxy is a reverse proxy — stable-pinning is the safer choice and per task rule:

```json
"checkver": {
    "url": "https://github.com/tobychui/zoraxy/releases.atom",
    "regex": "<title[^>]*>v(\\d+(?:\\.\\d+)+)</title>"
}
```

Verified against live feed titles (`v3.3.5-rc2`, `v3.3.5-rc1`, `v3.3.4`, …): first plain title = `v3.3.4` → version `3.3.4` = current manifest → checkver immediately GREEN, no bump.

- Alternative (track rcs instead of stable-pinning): `{"github": "https://github.com/tobychui/zoraxy", "regex": "v?([\\d.]+(?:-rc\\d+)?)"}` → `3.3.5-rc2`; asset `zoraxy_windows_amd64.exe` is version-independent and exists on `v3.3.5-rc2` ✓.
- Fragility note: tobychui ships ~2–4 rcs per minor (feed currently holds exactly 10 entries incl. both plain stables). If v3.3.5 spawns ≥5 more rcs, `v3.3.4` falls off the feed → checkver breaks.

### 9. revezone (`bucket/revezone.json`, manifest version `1.0.0-alpha.18`)

Current checkver (quoted):

```json
"checkver": {
    "github": "https://github.com/revezone/revezone"
}
```

Recent tags (all non-prerelease, **no `v` prefix**): `1.0.0-alpha.18`, `1.0.0-alpha.17`, `1.0.0-alpha.15`, `1.0.0-alpha.14`, `1.0.0-alpha.13` → latest = `1.0.0-alpha.18`.

- Plain stable: **none**. Manifest already at latest; asset `revezone-1.0.0-alpha.18-setup.exe` ✓.

Proposed:

```json
"checkver": {
    "github": "https://github.com/revezone/revezone",
    "regex": "v?([\\d.]+(?:-alpha(?:\\.\\d+)?)?)"
}
```

Verified: → `1.0.0-alpha.18`.

### 10–11. wsl-centos-7 / wsl-centos-8 (`mishamosher/CentOS-WSL`, one shared repo)

Current checkver (both, quoted): `"checkver": "github"` → homepage `https://github.com/mishamosher/CentOS-WSL` → `/releases/latest` → **`9-stream-20230626`** for BOTH manifests → default regex → `9-`. A plain `github` checkver can NEVER distinguish 7 vs 8: GitHub's "latest" is a single repo-wide tag and it is a 9-stream tag now. The two manifests must select their major from the release LIST.

Full release history (newest first, all non-prerelease):

```
7.9-2211, 9-stream-20230626, 8-stream-20230626, 9-stream-20220718, 9-stream-20220509,
9-stream-20220419, 7.9-2111, 9-stream-20220302, 8-stream-20220125, 8.4-2105, 7.9-2009,
6.10-1907, 8-stream-20210603, 8-stream-20210210, 8.3-2011, 8-stream-20201019, 8.2-2004, 7.8-2003
```

- **wsl-centos-7** (manifest version `7.9-2211`): newest 7.x tag = `7.9-2211` (already current). Asset on that release: `CentOS7.zip` ✓ (matches existing template).

  ```json
  "checkver": {
      "url": "https://github.com/mishamosher/CentOS-WSL/releases.atom",
      "regex": "<title[^>]*>CentOS (7[\\w.-]+)</title>"
  }
  ```

  Atom titles carry a `CentOS ` prefix (verified live: `CentOS 9-stream-20230626`, `CentOS 8-stream-20230626`, `CentOS 7.9-2211`, …). First `7…` match = `7.9-2211` → equals manifest → GREEN. Verified.

- **wsl-centos-8** (manifest version `8.4-2105` — OUTDATED): newest 8.x tag = `8-stream-20230626` (the 8 line moved to stream builds after CentOS 8 EOL). **⚠ Asset renamed**: that release ships `CentOS8-stream.zip` (NOT `CentOS8.zip`; verified asset list). Fixing checkver bumps version to `8-stream-20230626`, so the autoupdate URL template must ALSO change to `.../download/$version/CentOS8-stream.zip`, else autoupdate 404s.

  ```json
  "checkver": {
      "url": "https://github.com/mishamosher/CentOS-WSL/releases.atom",
      "regex": "<title[^>]*>CentOS (8[\\w.-]+)</title>"
  }
  ```

  → `8-stream-20230626`. Verified (first `8…` title match).
  - Also worth updating at implementation time: description ("CentOS 8" → stream build), notes (`CentOS8.zip` → `CentOS8-stream.zip` in wsl --import examples), and verify the zip's inner launcher exe name (`CentOS8.exe` shortcut may need adjusting — unverified, download required).
  - Version-comparison caveat [INFERENCE]: scoop compares `-`-delimited segments; `8-stream-20230626` vs old `8.4-2105` may not order as "newer" under `scoop status`, but excavator's autoupdate is driven by version-string inequality, so the manifest still gets bumped to the checkver result.

---

## Caveats / Risks

1. **Atom 10-entry window** (fx, zoraxy, both CentOS manifests): `releases.atom` exposes only ~10 newest entries. If enough newer releases ship before the pinned/stable target, the regex stops matching and checkver fails again. Mitigations: upstream release cadence is low for CentOS-WSL (dormant since 2023-06) and zoraxy stabilizes within ~4 rcs; fx is the highest risk (commit-per-alpha). Re-check during future excavator triage.
2. **project-86 `v2.0.0-alpha.2` has zero assets** — regex fix converts the B1 failure into a B2 autoupdate failure. Decide handling with the B2 round.
3. **wsl-centos-8 asset rename** `CentOS8.zip` → `CentOS8-stream.zip` must accompany the version bump.
4. HTML-mode (user without `GITHUB_TOKEN`) note: the github+regex proposals match the tag string inside the release-page HTML too (tag appears in `<title>`/og:meta), so they work in both API and HTML modes.
5. All proposed regexes were executed against the real tag strings / real atom titles (Python `re`, equivalent to .NET for these constructs) — see Verification below. The default-regex trailing-dash reproduction also matched all 10 tags exactly.

## Verification performed

- `gh api repos/{repo}/releases?per_page=6` for all 10 repos (tag_name + prerelease + draft flags) and `releases/latest` (latest non-prerelease) — quoted above per app.
- `gh api repos/{repo}/releases/tags/{tag}` asset listings for every proposed target version (froggit, airi, allusion, gclone×3 arches, fx, zoraxy, revezone, CentOS 7/8/9-stream).
- Live `curl https://github.com/{repo}/releases.atom` for metrue/fx, tobychui/zoraxy, mishamosher/CentOS-WSL (title lists quoted above).
- Regex suite: 21 assertions across the default-regex bug reproduction, all github+regex proposals, and all atom proposals — all pass except the initial froggit draft (documented: `.N` must be optional inside the suffix group), corrected and re-verified.
- Scoop core `bin/checkver.ps1` (master) fetched and quoted for the default-regex mechanism.

## Related

- A2RegexFacts research covers the other 21 regex-mismatch apps (separate file in this dir).
- prd.md scope item 2 (B1 list) is fully covered by this file; no B1 app was skipped.
