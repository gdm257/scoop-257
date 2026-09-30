# Research: A2 checkver-regex failures — upstream tag facts & proposed regexes

- **Query**: Fix checkver regex failures for 20 A2 apps + 3 version-semantics apps (OsuBeatmapDownloader, shutter-image-browser, onscripter-ru)
- **Scope**: external (GitHub upstream) + internal (manifests, scoop checkver source)
- **Date**: 2026-10-01
- **All proposed regexes below were validated empirically in BOTH checkver modes against live upstream data (see "Validation" at the end).**

---

## 1. Root cause (applies to all 20 A2 apps)

Every failing manifest uses `"checkver": {"github": "<repo>", "regex": "..."}`. Scoop's `bin/checkver.ps1` handles this form in **two mutually exclusive modes**:

- **CI / excavator (API mode)**: `excavator.yml` sets `GITHUB_TOKEN`. `Get-GitHubToken()` (lib/download.ps1:589) picks it up, checkver rewrites the URL to `https://api.github.com/repos/<o>/<r>/releases/latest`, sets `jsonpath = '$.tag_name'`, and the custom regex is matched against the **bare tag_name string only**.
- **Local `scoop checkver` without token (HTML mode)**: fetches `https://github.com/<o>/<r>/releases/latest` HTML; the regex is matched against the **whole page**, first match wins, capture group 1 is the version (checkver.ps1:390-410).

All 20 current regexes are HTML-mode regexes: they anchor on `releases/tag/…`, `<title>…`, or (veyon) asset filenames. On excavator they are applied to a bare tag like `fleet-v4.92.1`, where they can never match → `couldn't match '<regex>' in <url>`. Locally they still pass (verified), which is why this broke silently in CI only.

**Fix strategy**: strip the HTML-only context so the regex matches the tag body itself. Every proposed regex below was verified to ALSO still produce the correct version against the live HTML page (first-match), so local validation (`scoop checkver <name>`, HTML mode) and excavator (API mode) both work.

Two extra facts that force URL changes for 3 apps:

- **Modern GitHub release pages no longer contain asset filenames** in the initial HTML (assets load via a deferred `expanded_assets` fragment). Proven: veyon's asset-based regex fails even in HTML mode locally.
- GitHub's `<title>` is `Release <release-NAME> · <owner>/<repo> · GitHub` (uses the release **name** when set, not the tag). This is the only page location carrying the human version for repos whose tags are `26` or `untagged-…`.

Note: manifest-supplied `checkver.jsonpath` overrides the shorthand's default `$.tag_name` (checkver.ps1 sets the default first, lines 180-187, then applies `checkver.jp`/`checkver.jsonpath`, lines 228-233) — but only in API mode; in HTML mode a jsonpath breaks. So jsonpath-based fixes must use an explicit `checkver.url` pointing at the API JSON (deterministic in both environments; fetched anonymously since checkver only injects auth for the `github` shorthand). This bucket currently has **zero** manifests using explicit `api.github.com` checkver URLs, and anonymous GitHub API calls from shared CI runner IPs can hit the 60/h rate limit — therefore the preferred fix for the two name-based apps uses the HTML page, and only veyon (which needs asset names) uses the API JSON.

---

## 2. Per-app findings & proposed fixes

Format: manifest → current checkver (quoted verbatim) → upstream facts (latest + recent tags, prerelease) → proposed replacement `checkver` object (verbatim JSON, ready to paste) → expected post-fix output.

### 2.1 dango-translator — `bucket/dango-translator.json`

- Current: `{"github": "https://github.com/PantsuDango/Dango-Translator", "regex": "releases/tag/Ver\\.([\\d.]+)"}`
- Upstream `/releases/latest` → `Ver.6.3.3` (not a prerelease). Recent tags: `Ver.6.3.3`, `Ver6.3.1`, `Ver6.3.0`, `Ver6.2.2` — **naming is inconsistent**: only 6.3.3 has the dot after `Ver`, older tags are `Ver6.x.y`.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/PantsuDango/Dango-Translator",
    "regex": "Ver\\.?([\\d.]+)"
}
```

- `.?` tolerates both `Ver.` and `Ver` tag styles. Post-fix: `6.3.3` (scoop 4.5.8) → update available.
- ⚠️ Caveat (B2, out of scope this round): the autoupdate URL `releases/download/Ver.$version/zip_$version.zip` is dead for 6.x — actual assets on `Ver.6.3.3` are `DangoTranslator-v6.3.3-all.zip` / `DangoTranslator-v6.3.3-simple.zip` (+ `.exe`). Verified `zip_6.3.3.zip` → HTTP 404.

### 2.2 ffmpegfreeui — `bucket/ffmpegfreeui.json`

- Current: `{"github": "https://github.com/Lake1059/FFmpegFreeUI", "regex": "/releases/tag/([\\d.]+)"}`
- Upstream `/releases/latest` → `6.2.33` (not a prerelease; release *name* is `3FUI 6.2.33`). Recent tags: `6.2.33`, `6.2.32`, `6.2.31` — plain dotted numbers, no prefix.
- Bare-number tags are the hard case for dual-mode: a bare `([\\d.]+)` matches garbage digits early in HTML. The title contains the release *name* (`Release 3FUI 6.2.33`), so `Release ([\d.]+)` would capture `3`. Anchoring on the tag link works in both modes (in API mode `^` matches the start of the bare tag string):
- Proposed:

```json
"checkver": {
    "github": "https://github.com/Lake1059/FFmpegFreeUI",
    "regex": "(?:/releases/tag/|^)([\\d.]+)"
}
```

- Validated: API mode on `6.2.33` → `6.2.33`; HTML mode first match → `6.2.33` (canonical/og link `…/releases/tag/6.2.33`; the earlier `route-pattern` meta `/…/releases/tag/*name` cannot match because `*` blocks `[\d.]+`). Post-fix: `6.2.33` (scoop 5.2) → update available.

### 2.3 datax — `bucket/datax.json`

- Current: `{"github": "https://github.com/alibaba/DataX", "regex": "releases/tag/datax_v(\\d+)"}`
- Upstream `/releases/latest` → `datax_v202309` (not a prerelease). Recent tags: `datax_v202309`, `datax_v202308`, `datax_v202306` (last release 2023-09; upstream has moved on, but this is still the newest release).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/alibaba/DataX",
    "regex": "datax_v(\\d+)"
}
```

- Post-fix: `202309` == manifest `202309` → green.

### 2.4 hunt-and-peck — `bucket/hunt-and-peck.json`

- Current: `{"github": "https://github.com/zsims/hunt-and-peck", "regex": "releases/tag/release(?:%2F|/)([\\d.]+)"}`
- Upstream `/releases/latest` → `release/1.7` (not a prerelease). Recent tags: `release/1.7`, `release/1.6`, `release/1.5` — **tag contains a slash** (`release/x.y`); GitHub encodes it as `release%2F1.7` in some URL contexts, literal in others. The `(?:%2F|/)` alternation already handles both — only the `releases/tag/` prefix had to go.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/zsims/hunt-and-peck",
    "regex": "release(?:%2F|/)([\\d.]+)"
}
```

- Post-fix: `1.7` == manifest `1.7` → green. Autoupdate already uses `release%2F$version` (correct encoding for download URLs).

### 2.5 evil-helix — `bucket/evil-helix.json`

- Current: `{"github": "https://github.com/usagi-flow/evil-helix", "regex": "releases/tag/release-(\\d+)"}`
- Upstream `/releases/latest` → `release-20250915` (not a prerelease). Recent tags: `release-20250915`, `release-20250823`, `release-20250601` (date-based). Note: the plain `v0.x.y` tags in the repo are old and not releases.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/usagi-flow/evil-helix",
    "regex": "release-(\\d+)"
}
```

- Post-fix: `20250915` (scoop 20240716) → update available.

### 2.6 hatch — `bucket/hatch.json`

- Current: `{"github": "https://github.com/pypa/hatch", "regex": "releases/tag/hatch-v([\\d.]+)"}`
- Upstream `/releases/latest` → `hatch-v1.18.1` (not a prerelease). Recent releases: `hatch-v1.18.1`, `hatch-v1.18.0`, `hatch-v1.17.1`; the repo also publishes `hatchling-v1.32.x` releases (different product — the `hatch-v` prefix is what selects the right one). Full audit of all `hatch-v*` releases confirms `1.18.1` is the newest hatch release, so `/releases/latest` returning `hatch-v1.18.1` is correct, not a stale "latest" marker.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/pypa/hatch",
    "regex": "hatch-v([\\d.]+)"
}
```

- `hatch-v` cannot match inside `hatchling-v` (`hatch` is followed by `l`, not `-`). Post-fix: `1.18.1` (scoop 1.9.1) → update available (1.18.1 > 1.9.1 is a genuine version increase).

### 2.7 kotlin-lsp — `bucket/kotlin-lsp.json`

- Current: `{"github": "https://github.com/Kotlin/kotlin-lsp", "regex": "releases/tag/kotlin-lsp(?:%2F|/)v([\\d.]+)"}`
- Upstream `/releases/latest` → `kotlin-lsp/v263.4702.0` (not a prerelease). Recent tags: `kotlin-lsp/v263.4702.0`, `kotlin-lsp/v262.9593.0`, `kotlin-lsp/v262.8190.0` — namespace/slash prefix. (The `pycharm/…` tags in the repo are not releases.)
- Proposed:

```json
"checkver": {
    "github": "https://github.com/Kotlin/kotlin-lsp",
    "regex": "kotlin-lsp(?:%2F|/)v([\\d.]+)"
}
```

- Post-fix: `263.4702.0` (scoop 262.2310.0) → update available.
- ⚠️ Caveat (B2): autoupdate URL `https://download-cdn.jetbrains.com/kotlin-lsp/263.4702.0/…` currently returns **404** (verified; `…/262.2310.0/…` returns 200). JetBrains hasn't mirrored 263.4702.0 on that CDN path — the checkver fix will surface this as a download failure; handle in the B2 round.

### 2.8 fleetctl — `bucket/fleetctl.json`

- Current: `{"github": "https://github.com/fleetdm/fleet", "regex": "releases/tag/fleet-v([\\d.]+)"}`
- Upstream `/releases/latest` → `fleet-v4.92.1` (not a prerelease). Recent tags: `fleet-v4.92.1`, `fleet-v4.92.0`, `fleet-v4.91.1` (repo also has `v4.92.1`-style tags without prefix — same versions, harmless).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/fleetdm/fleet",
    "regex": "fleet-v([\\d.]+)"
}
```

- Post-fix: `4.92.1` (scoop 4.38.0) → update available.

### 2.9 foundation-sunshine — `bucket/foundation-sunshine.json`

- Current: `{"github": "https://github.com/AlkaidLab/foundation-sunshine", "regex": "<title>Release v([^\\s<]+)"}`
- Upstream `/releases/latest` → `v2026.925.152547.杂鱼` (not a prerelease). Recent releases: `v2026.930.90420.杂鱼` (**prerelease**), `v2026.930.42047.杂鱼` (**prerelease**), `v2026.925.152547.杂鱼` (stable, latest). `<title>` regexes are HTML-only by construction; tag ends with the CJK suffix `杂鱼` (constant across all tags).
- Proposed (manifest must stay UTF-8; raw CJK in the JSON value):

```json
"checkver": {
    "github": "https://github.com/AlkaidLab/foundation-sunshine",
    "regex": "v([\\d.]+\\.杂鱼)"
}
```

- Validated: API mode → `2026.925.152547.杂鱼`; HTML mode first match (raw CJK in `<title>Release v2026.925.152547.杂鱼 · …`) → same. The `.杂鱼` suffix makes false positives impossible. Post-fix: `2026.925.152547.杂鱼` (scoop `2026.324.103456.杂鱼`) → update available. Note the manifest has **no autoupdate** — this only fixes version reporting. Two newer prereleases exist; `/releases/latest` correctly tracks stable.

### 2.10 JHenTai — `bucket/JHenTai.json`

- Current: `{"github": "https://github.com/jiangtian616/JHenTai", "regex": "releases/tag/v(?<base>[\\d.]+)(?:\\+|%2B)(?<build>\\d+)", "replace": "${base}+${build}"}`
- Upstream `/releases/latest` → `v8.0.16+334` (not a prerelease). Recent tags: `v8.0.16+334`, `v8.0.16`, `v8.0.15`, `v8.0.14+328` — build suffix only on some tags.
- Proposed (keep `replace`; drop only the HTML prefix):

```json
"checkver": {
    "github": "https://github.com/jiangtian616/JHenTai",
    "regex": "v(?<base>[\\d.]+)(?:\\+|%2B)(?<build>\\d+)",
    "replace": "${base}+${build}"
}
```

- Post-fix: `8.0.16+334` == manifest → green (verified locally too: local checkver already prints `JHenTai: 8.0.16+334`). Named groups `base`/`build` preserved — autoupdate uses `$matchBase%2B$matchBuild` (URL-encodes the `+`), still correct.

### 2.11 iii — `bucket/iii.json`

- Current: `{"github": "https://github.com/iii-hq/iii", "regex": "releases/tag/iii(?:%2F|/)v([\\d.]+)"}`
- Upstream `/releases/latest` → `iii/v0.24.3` (not a prerelease). Newer releases exist but are prereleases: `iii/v0.24.4-rc.1` (**prerelease**), `iii-alpha/v0.24.3-alpha.2` (**prerelease**). Repo also has stray non-release tags (`vv0.2.1-beta.37`, `v1.0.0-rc.26`) — `iii(?:%2F|/)` cannot match `iii-alpha/…` (a `-` follows `iii`).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/iii-hq/iii",
    "regex": "iii(?:%2F|/)v([\\d.]+)"
}
```

- Post-fix: `0.24.3` == manifest → green.

### 2.12 nsmusics — `bucket/nsmusics.json`

- Current: `{"github": "https://github.com/Super-Badmen-Viper/NSMusicS", "regex": "releases/tag/NSMusicS-v([\\d.]+)"}`
- Upstream `/releases/latest` → `NSMusicS-v2.3.1` (not a prerelease). Recent tags: `validate-NSMusicS-v2.3.1` (not a release), `NSMusicS-v2.3.1`, `NSMusicS-v2.3.0`, `NSMusicS-v2.2.6`; there is also a junk release tagged `NSMusicS-Win-Update` (older, not latest).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/Super-Badmen-Viper/NSMusicS",
    "regex": "NSMusicS-v([\\d.]+)"
}
```

- In API mode the page is exactly the tag name, so `validate-…` can't interfere; in HTML mode the `<title>` (`Release NSMusicS-v2.3.1 · …`) is the first occurrence. Post-fix: `2.3.1` == manifest → green.

### 2.13 real-video-enhancer — `bucket/real-video-enhancer.json`

- Current: `{"github": "https://github.com/TNTwise/REAL-Video-Enhancer", "regex": "releases/tag/RVE-([\\d.]+)"}`
- Upstream `/releases/latest` → `RVE-2.4.1` (not a prerelease). Newer `RVE-2.4.2` exists but is marked **prerelease** ("Pre-Release"), so `/releases/latest` stays on 2.4.1 — correct stable-tracking.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/TNTwise/REAL-Video-Enhancer",
    "regex": "RVE-([\\d.]+)"
}
```

- Post-fix: `2.4.1` == manifest → green.

### 2.14 peri — `bucket/peri.json`

- Current: `{"github": "https://github.com/KonghaYao/peri", "regex": "releases/tag/agent-v([\\d.]+)"}`
- Upstream `/releases/latest` → `agent-v3.19.4` (not a prerelease). Recent tags: `agent-v3.19.4`, `agent-v3.19.3`, `agent-v3.19.2` (repo also has `relay-v*` releases — different component; `agent-v` selects correctly).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/KonghaYao/peri",
    "regex": "agent-v([\\d.]+)"
}
```

- Post-fix: `3.19.4` == manifest → green.

### 2.15 rivet — `bucket/rivet.json`

- Current: `{"github": "https://github.com/Ironclad/rivet", "regex": "releases/tag/app-v([\\d.]+)"}`
- Upstream `/releases/latest` → `app-v1.11.3` (not a prerelease). The releases feed interleaves two products: `app-v1.11.3` (Rivet IDE) and `v1.25.0` (Rivet Libraries) — `app-v` is the correct selector.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/Ironclad/rivet",
    "regex": "app-v([\\d.]+)"
}
```

- Post-fix: `1.11.3` == manifest → green.

### 2.16 translumo — `bucket/translumo.json`

- Current: `{"github": "https://github.com/ramjke/Translumo", "regex": "releases/tag/v\\.([\\d.]+)"}`
- Upstream `/releases/latest` → `v.1.1.0` (not a prerelease). Recent tags: `v.1.1.0`, `v.1.0.2`, `v.1.0.1` — unusual `v.` prefix (dot immediately after v), consistent for years.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/ramjke/Translumo",
    "regex": "v\\.([\\d.]+)"
}
```

- Post-fix: `1.1.0` == manifest → green.

### 2.17 pachi — `bucket/pachi.json`

- Current: `{"github": "https://github.com/pasky/pachi", "regex": "releases/tag/pachi-([\\d.]+)"}`
- Upstream `/releases/latest` → `pachi-12.90` (not a prerelease). Recent tags: `pachi-12.90`, `pachi-12.90-homebrew`, `pachi-12.88`, `pachi-12.86`; the feed also contains a non-version release `katago_models` (ignored by the regex).
- Proposed:

```json
"checkver": {
    "github": "https://github.com/pasky/pachi",
    "regex": "pachi-([\\d.]+)"
}
```

- Post-fix: `12.90` (scoop 12.84) → update available.

### 2.18 veyon — `bucket/veyon.json`  *(needs URL change)*

- Current: `{"github": "https://github.com/veyon/veyon", "regex": "veyon-([\\d.]+)-win64-setup"}`
- Upstream `/releases/latest` → tag `v4.11.3` (not a prerelease). Recent tags: `v4.11.3`, `v4.11.2`, `v4.11.1` (a stray `v4.99.0` tag exists but is not a release). **Tags are 3-component (`v4.11.3`) while the product/asset version is 4-component (`veyon-4.11.3.0-win64-setup.exe`)** — manifest `version` is `4.11.3.0`.
- The regex is asset-name-based; asset names no longer appear in release-page HTML (verified: `scoop checkver veyon` fails locally with `couldn't match 'veyon-([\d.]+)-win64-setup' in https://github.com/veyon/veyon/releases/latest`), and the bare tag can't yield the 4-component version. The only reliable source is the release JSON's asset list → point checkver at the API endpoint explicitly:
- Proposed (regex unchanged, `github` shorthand → explicit `url`):

```json
"checkver": {
    "url": "https://api.github.com/repos/veyon/veyon/releases/latest",
    "regex": "veyon-([\\d.]+)-win64-setup"
}
```

- Validated against the anonymous API JSON: captures `4.11.3.0` == manifest → green. Autoupdate keeps working: `$matchHead` is derived from the version string by scoop (`4.11.3.0` → head `4.11.3`), producing `download/v4.11.3/veyon-4.11.3.0-win64-setup.exe` (asset exists, verified).
- ⚠️ This is the one manifest now using an explicit `api.github.com` URL (no bucket precedent): checkver does not attach the CI token to explicit URLs, so this is 1 anonymous API call per excavator run (60/h per-IP anonymous limit; acceptable for a single manifest, but don't mass-adopt this pattern).

### 2.19 wakatime — `bucket/wakatime.json`

- Current: `{"github": "https://github.com/wakatime/desktop-wakatime", "regex": "releases/tag/(?<base>v[\\d.]+)(?:\\+|%2B)(?<build>\\d+)", "replace": "${base}+${build}"}`
- Upstream `/releases/latest` → `v3.0.0+1` (not a prerelease). Recent tags: `v3.0.0+1`, `v3.0.0`, `v2.1.7`, `v2.1.6`.
- Proposed (keep `replace`; drop only the HTML prefix):

```json
"checkver": {
    "github": "https://github.com/wakatime/desktop-wakatime",
    "regex": "(?<base>v[\\d.]+)(?:\\+|%2B)(?<build>\\d+)",
    "replace": "${base}+${build}"
}
```

- Post-fix: `v3.0.0+1` == manifest → green (local checkver already prints exactly this).

### 2.20 q5go — `bucket/q5go.json`

- Current: `{"github": "https://github.com/bernds/q5Go", "regex": "releases/tag/q5go-([\\d.]+)"}`
- Upstream `/releases/latest` → `q5go-2.1.3` (not a prerelease). Recent tags: `q5go-2.1.3`, `q5go-2.1.2`, `q5go-2.1.1`.
- Proposed:

```json
"checkver": {
    "github": "https://github.com/bernds/q5Go",
    "regex": "q5go-([\\d.]+)"
}
```

- Post-fix: `2.1.3` == manifest → green.

---

## 3. Version-semantics apps

### 3.1 OsuBeatmapDownloader — `bucket/OsuBeatmapDownloader.json`

- Current: `"checkver": "github"` (default regex). `version: 2.6`, no autoupdate; install URL pinned to `releases/download/26/Release-x86.zip`.
- Upstream `KyuubiRan/BeatmapDownloader` `/releases/latest`: **tag_name = `26`, release name = `2.6`** (not a prerelease). Tags are dotless squashed versions: `26`, `25`, `24`, `23` …
- What checkver produces: API mode matches `(?:v|V)?([\d.-]+)` on bare tag `26` → **`26`**; HTML mode matches `/releases/tag/26` → **`26`** (verified locally: `OsuBeatmapDownloader: 26 (scoop version is 2.6)`). `26 > 2.6` → permanent false "update available".
- The real version string only exists in the release **name** (`2.6`), which GitHub renders as the page `<title>` (`Release 2.6 · KyuubiRan/BeatmapDownloader · GitHub`, first occurrence at ~byte 20k, all 3 occurrences identical). Explicit-URL HTML checkver is deterministic in both environments and needs no API token:
- Proposed:

```json
"checkver": {
    "url": "https://github.com/KyuubiRan/BeatmapDownloader/releases/latest",
    "regex": "Release v?([\\d.]+)"
}
```

- Validated: HTML → `2.6` == manifest → green.
- Alternative (more precise, but anonymous-API): `{"url": "https://api.github.com/repos/KyuubiRan/BeatmapDownloader/releases/latest", "jsonpath": "$.name", "regex": "v?([\\d.]+)"}`.
- ⚠️ Future-proofing note: upstream's squashed tag scheme is ambiguous past 2.9 (tag `210` would mean 2.10) — the name-based regex above is immune to that; any tag-based transform is not.

### 3.2 shutter-image-browser — `bucket/shutter-image-browser.json`

- Current: `"checkver": "github"` (default regex). `version: 1.4`, no autoupdate; URL pinned to `releases/download/v1.4/Shutter-Win64_1.4_20221013.7z`.
- Upstream `dream7180/Shutter-cn` `/releases/latest`: tag `v1.4.1`, release name `1.4.1`, **not a prerelease**. Recent tags: `v1.4.1`, `v1.4`, `v1.3`. The v1.4.1 release has the Windows asset `Shutter-Win64_1.4.1_20230330.7z` (verified).
- What checkver produces: `1.4.1` in both modes (verified locally: `shutter-image-browser: 1.4.1 (scoop version is 1.4)`).
- **Finding: there is no regex bug here.** `1.4.1 > 1.4` is a *true* positive — upstream really is one patch release ahead and the manifest is simply stale (v1.4.1 shipped 2023-03-30). Recommended fix is to bump the manifest to `1.4.1` + `url` → `https://github.com/dream7180/Shutter-cn/releases/download/v1.4.1/Shutter-Win64_1.4.1_20230330.7z` (new hash required) and keep `"checkver": "github"` as-is.
- If the bucket deliberately wants to stay pinned at 1.4 and silence the report, the only regex that does that is a minor-truncating one — `{"github": "https://github.com/dream7180/Shutter-cn", "regex": "v(\\d+\\.\\d+)"}` (captures `1.4` from `v1.4.1`) — **discouraged**: it permanently masks all patch-level updates (would also report 1.5 correctly, but never 1.4.2+).

### 3.3 onscripter-ru — `bucket/onscripter-ru.json`

- Current: `"checkver": "github"` (default regex). `version: r3570`, no autoupdate; URL pinned to `releases/download/untagged-b87158b67d23f44f53d3/onscripter-ru_win_r3570.zip`.
- Upstream `umineko-project/onscripter-ru` `/releases/latest`: **tag_name = `untagged-b87158b67d23f44f53d3`** (GitHub auto-generated for a release published without/with deleted tag), **release name = `ONScripter-RU r3570`** (not a prerelease). All recent releases follow this pattern (`untagged-<hash>` tag, `ONScripter-RU r<N>` name); the real revision lives only in the name (and asset filenames `onscripter-ru_win_r3570.zip`).
- What checkver produces: API mode applies `(?:v|V)?([\d.-]+)` to `untagged-b87158b67d23f44f53d3` → the first `[\d.-]+` run is the `-` right after `untagged` → **`-`** (the excavator symptom). HTML mode: `couldn't match '/releases/tag/(?:v|V)?([\d.-]+)'` (verified locally) because the only tag link is the untagged hash.
- Proposed (HTML title carries the release name; all 3 page occurrences of `ONScripter-RU r3570` identical, first is `<title>`):

```json
"checkver": {
    "url": "https://github.com/umineko-project/onscripter-ru/releases/latest",
    "regex": "ONScripter-RU (r\\d+)"
}
```

- Validated: HTML → `r3570` == manifest → green (group includes the `r`, matching the manifest's `r3570` version semantics).
- Alternative (anonymous-API): `{"url": "https://api.github.com/repos/umineko-project/onscripter-ru/releases/latest", "jsonpath": "$.name", "regex": "(r\\d+)"}`.
- ⚠️ This app can never have working autoupdate: the download URL's tag segment is an `untagged-<hash>` that changes every release. Checkver fix only makes version reporting correct; future updates stay manual.

---

## 4. Validation

Method: for each app, (a) API mode — apply regex to the exact `/releases/latest` `tag_name` returned by `gh api`; (b) HTML mode — fetch `https://github.com/<repo>/releases/latest` with redirect-following curl and take the FIRST regex match over the whole page, mimicking checkver.ps1:390-410. Cross-checked against real `scoop checkver` runs (HTML mode) via this bucket's `bin/checkver.ps1` shim. Named-group regexes simulated with `(?P<…>)` translation (equivalent semantics); `replace` outputs verified for JHenTai (`8.0.16+334`) and wakatime (`v3.0.0+1`) by actual local runs.

| app | latest tag | current regex: API / HTML | proposed regex: API / HTML | post-fix vs manifest |
|---|---|---|---|---|
| dango-translator | `Ver.6.3.3` | FAIL / 6.3.3 | 6.3.3 / 6.3.3 | update (4.5.8) |
| ffmpegfreeui | `6.2.33` | FAIL / 6.2.33 | 6.2.33 / 6.2.33 | update (5.2) |
| datax | `datax_v202309` | FAIL / 202309 | 202309 / 202309 | green |
| hunt-and-peck | `release/1.7` | FAIL / 1.7 | 1.7 / 1.7 | green |
| evil-helix | `release-20250915` | FAIL / 20250915 | 20250915 / 20250915 | update (20240716) |
| hatch | `hatch-v1.18.1` | FAIL / 1.18.1 | 1.18.1 / 1.18.1 | update (1.9.1) |
| kotlin-lsp | `kotlin-lsp/v263.4702.0` | FAIL / 263.4702.0 | 263.4702.0 / 263.4702.0 | update (262.2310.0) |
| fleetctl | `fleet-v4.92.1` | FAIL / 4.92.1 | 4.92.1 / 4.92.1 | update (4.38.0) |
| foundation-sunshine | `v2026.925.152547.杂鱼` | FAIL / ok | ok / ok (same value) | update (2026.324…) |
| JHenTai | `v8.0.16+334` | FAIL / 8.0.16+334 | 8.0.16+334 / 8.0.16+334 | green |
| iii | `iii/v0.24.3` | FAIL / 0.24.3 | 0.24.3 / 0.24.3 | green |
| nsmusics | `NSMusicS-v2.3.1` | FAIL / 2.3.1 | 2.3.1 / 2.3.1 | green |
| real-video-enhancer | `RVE-2.4.1` | FAIL / 2.4.1 | 2.4.1 / 2.4.1 | green |
| peri | `agent-v3.19.4` | FAIL / 3.19.4 | 3.19.4 / 3.19.4 | green |
| rivet | `app-v1.11.3` | FAIL / 1.11.3 | 1.11.3 / 1.11.3 | green |
| translumo | `v.1.1.0` | FAIL / 1.1.0 | 1.1.0 / 1.1.0 | green |
| pachi | `pachi-12.90` | FAIL / 12.90 | 12.90 / 12.90 | update (12.84) |
| veyon | `v4.11.3` | FAIL / FAIL | 4.11.3.0 (API JSON) | green |
| wakatime | `v3.0.0+1` | FAIL / v3.0.0+1 | v3.0.0+1 / v3.0.0+1 | green |
| q5go | `q5go-2.1.3` | FAIL / 2.1.3 | 2.1.3 / 2.1.3 | green |
| OsuBeatmapDownloader | `26` (name `2.6`) | 26 / 26 | 2.6 (HTML title) | green |
| shutter-image-browser | `v1.4.1` | 1.4.1 / 1.4.1 | no change needed | true update (1.4) |
| onscripter-ru | `untagged-…` (name `…r3570`) | `-` / no-match | r3570 (HTML title) | green |

("FAIL" = regex does not match; HTML values for foundation-sunshine abbreviated for width — full value `2026.925.152547.杂鱼` in both modes.)

---

## 5. Caveats / follow-ups for the implement round

1. **dango-translator autoupdate is dead** for 6.x: assets renamed to `DangoTranslator-v<ver>-{all,simple}.{exe,zip}` and the `Ver.`-with-dot tag spelling is inconsistent (`Ver.6.3.3` but `Ver6.3.1`). The regex fix is safe either way; fixing autoupdate belongs to the B2 round.
2. **kotlin-lsp**: JetBrains CDN has no `263.4702.0` artifacts (404; `262.2310.0` = 200). Checkver fix will correctly report the new version; the autoupdate download will fail until the CDN catches up or the URL pattern changes (B2).
3. **veyon** is the only manifest moved to an explicit `api.github.com` checkver URL → anonymous API call in CI (no token attached to explicit URLs). One call per run is fine; do not replicate this pattern broadly.
4. **foundation-sunshine / iii / real-video-enhancer** track the latest **stable** release; newer prereleases exist (`v2026.930.*.杂鱼`, `iii/v0.24.4-rc.1`, `RVE-2.4.2`). If the bucket wants prereleases instead, the URL must change to the `/releases` feed — not requested here.
5. **shutter-image-browser**: evidence says stale manifest, not a regex bug (see §3.2) — decide bump-vs-ignore in the implement round.
6. All proposed `checkver.github` regexes keep the `github` shorthand so excavator keeps using the **authenticated** API (no rate-limit exposure); only veyon (mandatory) and OsuBeatmapDownloader/onscripter-ru (HTML page, no API involved) change `checkver` shape.
7. Manifests must remain UTF-8 (raw `杂鱼` in foundation-sunshine's regex; the bucket's `bin/formatjson.ps1` must not escape/re-encode it).

## Caveats / Not Found

- Nothing unresolved for the 23 assigned apps. Upstream repo of every app is alive with a reachable non-prerelease latest release (hunt-and-peck's `/releases/latest` needed one retry — transient EOF, then returned `release/1.7`).
- Exact CI failure lines from excavator run #36732909371 were not re-fetched (log not retained in the task dir); the API/HTML mode mechanics were proven from scoop's checkver source (D:/home/apps/scoop/apps/scoop/current/bin/checkver.ps1:155-191, 390-410), the workflow's `GITHUB_TOKEN` env, and reproduced empirically (current regexes fail API mode / pass HTML mode for all 20).
