# Research: A1 dead-upstream trio + own projects (chrome-plus, WinDeckHelper, softalk, git-ssh-sign, octopus-257)

- **Query**: Excavator checkver failures for chrome-plus / WinDeckHelper / softalk / git-ssh-sign / octopus-257 — upstream state, root cause, proposed fixed checkver regex
- **Scope**: mixed (repo manifests + external GitHub/web facts)
- **Date**: 2026-10-01

## Tooling deviation (important for interpreting the evidence)

Every `bash` call in this environment is gated ("Requires review (non-interactive mode)") — **`gh api` and `curl` were unavailable**. All external facts were gathered with the harness `read` tool fetching web URLs directly:

- `github.com` HTML pages, `*.atom` feeds (raw via `:raw`), and `raw.githubusercontent.com` fetch fine; redirects are followed (effective URL reported), so a 404 means gone, not renamed-with-redirect.
- `api.github.com` URLs return HTTP 403 (unauthenticated rate limit) — avoid; prerelease booleans were inferred from `releases/latest` redirect behavior instead (see octopus section).
- `softalk.stars.ne.jp` was fetched successfully only via the tool's reader-proxy fallback (method `jina`) — content is confirmed live, but *direct* reachability from this machine was not proven (see softalk caveats).

## How scoop `checkver: "github"` actually works (source-verified — read this first)

Verified against `ScoopInstaller/Scoop` master `bin/checkver.ps1` (fetched 2026-10-01; the repo no longer has `lib/checkver.ps1` — logic lives in `bin/checkver.ps1`). The bucket's own `bin/checkver.ps1` is a thin wrapper that delegates to the installed Scoop's copy, so these semantics govern both `scoop checkver` and the excavator:

1. `checkver: "github"` (or `checkver.github: <repo-url>`) → URL becomes `<repo>/releases/latest`.
2. **If a GitHub token is configured** (`Get-GitHubToken` — the excavator CI sets one; a local `gh auth` does too): URL is rewritten to `api.github.com/repos/<owner>/<repo>/releases/latest` with an `Authorization` header, and **`jsonpath` defaults to `$.tag_name`**.
3. Matching order in the completion handler: when jsonpath and regex are both present, jsonpath extracts `$.tag_name` first, then **`$page = $ver` — the custom regex is matched against the tag_name string ONLY** (first match, group 1 = version). A regex like `releases/tag/v(...)` can never match tag_name `v1.2.3` → `couldn't match '<regex>'`.
4. Without a token (HTML mode), the *default* regex is `/releases/tag/(?:v|V)?([\d.-]+)` matched against the whole HTML page — this is why `releases/tag/...`-style regexes appear to work when run tokenless but fail under the excavator.
5. API-mode **default** regex `(?:v|V)?([\d.-]+)` has no letters in the class — on tag `v0.13.9-post.1` it captures `0.13.9-` (broken). An explicit regex is required for `-post.N` tags.
6. Manifests **without** `checkver` are never queued (`if ($json.checkver) { $Queue += ... }`) — removing `checkver` legitimately removes an app from excavator checkver runs (they show up only in the bucket's `bin/missing-checkver.ps1` report).

## 1. chrome-plus — upstream DEAD (account deleted); no regex fix exists

Manifest (`bucket/chrome-plus.json`, quoted):

```json
"version": "1.18.2",
"homepage": "https://github.com/Bush2021/chrome_plus",
"url": "https://github.com/Bush2021/chrome_plus/releases/download/1.18.2/Chrome++_v1.18.2_x86_x64_arm64.7z",
"checkver": "github",
"autoupdate": { "architecture": { "64bit": {
    "url": "https://github.com/Bush2021/chrome_plus/releases/download/$version/Chrome++_v$version_x86_x64_arm64.7z" } } }
```

### Confirmed facts

- `https://github.com/Bush2021/chrome_plus` → **HTTP 404** (repo gone).
- `https://github.com/Bush2021` (profile) → **HTTP 404** → **the account itself is deleted/suspended**. Not a rename (GitHub profiles don't 404 on rename).
- `https://github.com/shuax/chrome_plus` → **HTTP 404** too. shuax (耍下) is the original author; surviving repo `icy37785/chrome_plus` is self-described "备份耍下的源码" (backup of shuax's source), confirming the lineage.
- GitHub repo search `chrome_plus in:name` (142 results, best-match AND stars-sorted). C++ "Chrome 增强软件" candidates:
  - **Ryanjiena/chrome_plus** — the only one still updated (Jul 2026). 3★, 5 forks, MIT. Exactly **one release: tag `1.5.4`** (released Oct 16 2025, 6 assets, 3 commits to main since). README: builds via GitHub Actions, "download" links to `nightly.link/shuax/chrome_plus/workflows/build/main` (unversioned CI artifacts; README not updated from shuax era).
  - icy37785/chrome_plus — 75★, last updated Oct 2023, self-described source backup.
  - yumaoss/chrome_plus — 59★, last updated May 2022.
  - No high-star actively-maintained successor exists.
- Bush2021's release assets died with the repo ⇒ the manifest's **install URL is also dead**, not just checkver.

### Proposed fix

No checkver-only fix is possible — there is nothing to point at in `Bush2021/chrome_plus`. Options for the maintainer:

- **(a) Remove the manifest** (recommended reading of the facts: upstream and its assets are gone).
- **(b) Re-point to `Ryanjiena/chrome_plus`** — only actively-maintained fork, has real release assets. Would need: homepage/url/autoupdate host swap, version lineage reset to `1.5.4` (tag has **no** `v`; asset naming must be confirmed against the 6 assets of that release), and checkver `{"github": "https://github.com/Ryanjiena/chrome_plus", "regex": "([\\d.]+)$"}`-style (tag without `v` → regex `^([\d.]+)$` or just `([\d.]+)` in API mode). Downside: 3★ personal fork, future releases not guaranteed, nightly.link-only distribution after 1.5.4.

## 2. WinDeckHelper — repo alive, but ALL releases/tags deleted; install URL dead too

Manifest (`bucket/WinDeckHelper.json`, quoted):

```json
"version": "2.3.5",
"homepage": "https://github.com/anejolov/WinDeckHelper",
"url": "https://github.com/anejolov/WinDeckHelper/archive/refs/tags/v2.3.5.zip",
"extract_dir": "WinDeckHelper-2.3.5",
"checkver": "github",
"autoupdate": { "architecture": { "64bit": {
    "url": "https://github.com/anejolov/WinDeckHelper/archive/refs/tags/v$version.zip",
    "extract_dir": "WinDeckHelper-$version" } } }
```

### Confirmed facts

- Repo exists: public, 68★, 1 fork, PowerShell, only branch is **`main`** (updated Jul 31 2025, per branches page).
- **Zero releases**: `/releases` page renders "There aren't any releases here".
- **Zero tags**: `tags.atom` (raw XML) contains no `<entry>` elements.
- **Tag `v2.3.5` does NOT exist**: `https://github.com/anejolov/WinDeckHelper/archive/refs/tags/v2.3.5.zip` redirects to codeload and returns **HTTP 404** ⇒ the manifest's current install URL is broken, not just checkver. (The ref `/tree/v2.3.5` still resolves to the old commit tree — an orphaned historical ref — but that is not a tag.)
- README at that old ref still says "Download latest version → `releases/tag/v2.3.1`" — releases once existed and were deleted. Current main README's download instructions: "Click on `<> Code` and then 'Download ZIP'" — i.e. distribution is now **the main branch zip, with no versioning at all**.

### Proposed fix

No version artifact exists upstream, so no checkver URL/regex can work. Options:

- **(a) Pin to main, drop auto-update**: `url` → `https://github.com/anejolov/WinDeckHelper/archive/refs/heads/main.zip`, `extract_dir` → `WinDeckHelper-main`, delete `checkver` + `autoupdate`, refresh hash manually when desired. (Excavator skips checkver-less manifests — verified in checkver.ps1 semantics, point 6 above.)
- **(b) Remove the manifest.**
- A tags.atom/releases.atom-based checkver is NOT possible — both feeds are empty.

## 3. softalk — old host dead; distribution MOVED to softalk.stars.ne.jp (live, latest = 020108)

Manifest (`bucket/softalk.json`, quoted):

```json
"version": "020101",
"url": "http://blitz.starfree.jp/download/SofTalk/New/stn020101.zip",
"checkver": {
    "url": "http://blitz.starfree.jp/download/SofTalk/New/",
    "xpath": "substring-before(//div/center/a[@href[contains(.,'.zip')]]/text(), '.zip')"
},
"autoupdate": { "url": "http://blitz.starfree.jp/download/SofTalk/New/stn$version.zip" }
```

### Confirmed facts

- Old host `blitz.starfree.jp` is unreachable from here on both schemes:
  - `http://…/download/SofTalk/New/` → connection failed ("socket connection was closed unexpectedly").
  - `https://…/download/SofTalk/New/` → "unknown certificate verification error".
  - PRD reports the same URL timing out on the CI runner. (Dead vs geo-blocked cannot be distinguished from here without `curl`; either way it is unusable for the excavator.)
- Official atwiki site (`https://w.atwiki.jp/softalk/`, homepage field) is **alive** (top page last updated 2026-02-05). Its download page (`pages/15.html`, updated 2026-02-05) says:
  - 最新バージョン (latest version) → Vector: `http://www.vector.co.jp/soft/winnt/art/se412443.html`
  - 旧バージョン (old versions) → **`https://softalk.stars.ne.jp/download/#SofTalk`** — the distribution site moved from `blitz.starfree.jp` (starfree.jp is the free tier of the same Japanese host, Star Server / stars.ne.jp).
- **New host is live**: `https://softalk.stars.ne.jp/download/SofTalk/New/` renders a directory listing containing exactly one archive: **`stn020108.zip`** (link: `https://softalk.stars.ne.jp/download/SofTalk/New/stn020108.zip`).
  - ⇒ Latest version is **020108**; the bucket's 020101 is 7 patch-levels behind.
  - Naming pattern unchanged: `stn` + 6-digit version + `.zip`; single "latest" zip in `New/` (old builds moved to the download/#SofTalk archive section).

### Proposed fix

Move all three URLs from `blitz.starfree.jp` to `softalk.stars.ne.jp` (path identical). Prefer a regex over the old xpath (the raw HTML structure of the new page was not inspected; regex on page text is structure-agnostic, and the link text itself is `stn020108.zip`):

```json
"checkver": {
    "url": "https://softalk.stars.ne.jp/download/SofTalk/New/",
    "regex": "stn([\\d]+)\\.zip"
},
"autoupdate": { "url": "https://softalk.stars.ne.jp/download/SofTalk/New/stn$version.zip" }
```

- Regex captures `020108` from `stn020108.zip`, matching the manifest's 6-digit `version` format and `stn$version.zip`.
- Also update the install `url` (and `hash` after download) to the new host.

### Caveats

- New-host fetch succeeded via the read tool's reader-proxy (jina), not a direct connection; direct + CI-runner reachability of `stars.ne.jp` unverified from here. Vector (`vector.co.jp`) is the official "latest version" page and a fallback checkver source, but it is a JS-heavy portal page and fragile to scrape.

## 4. git-ssh-sign — config bug: checkver points at the bucket repo, which has no releases

Manifest (`bucket/git-ssh-sign.json`, quoted):

```json
"version": "1.1.0",
"homepage": "https://github.com/gdm257/scoop-257",
"url": ["https://raw.githubusercontent.com/gdm257/scoop-257/refs/heads/master/LICENSE"],
"checkver": "github",
"autoupdate": { "url": ["https://raw.githubusercontent.com/gdm257/scoop-257/refs/heads/master/LICENSE"] }
```

(The actual `git-ssh-sign` script is written inline by `installer.script`; the only downloaded file is the bucket's own LICENSE.)

### Confirmed facts

- "Real upstream": **none exists** — the app is authored entirely inside this manifest (script embedded in `installer.script`, license pulled from the bucket repo itself). Homepage = the bucket.
- `gdm257/scoop-257`: `releases.atom` **empty** AND `tags.atom` **empty** (raw XML, no `<entry>`) ⇒ zero releases, zero tags.
- Root cause: `checkver: "github"` + homepage `gdm257/scoop-257` → `api.github.com/repos/gdm257/scoop-257/releases/latest` → **404** (no releases exist).

### Proposed fix (two options — maintainer's call)

- **(a) Delete `checkver` + `autoupdate` and maintain manually.** The app's content only changes when the manifest itself is edited, so version bumps are manifest edits by definition. Verified in checkver.ps1 source: manifests without `checkver` are excluded from the checkver queue entirely, so this silences the excavator failure legitimately (the app then appears only in `bin/missing-checkver.ps1` output).
- **(b) Self-host the version**: start tagging the bucket repo, e.g. tag `git-ssh-sign-v1.1.0` on the commit that carries that version, and:

```json
"checkver": {
    "url": "https://github.com/gdm257/scoop-257/tags.atom",
    "regex": "git-ssh-sign-v([\\d.]+)"
},
"autoupdate": { "url": ["https://raw.githubusercontent.com/gdm257/scoop-257/refs/heads/master/LICENSE"] }
```

  (tags.atom is a plain page fetch — no token/HTML-mode pitfalls; requires tagging discipline on every git-ssh-sign change.)

## 5. octopus-257 — pure regex-vs-mode bug; releases healthy, latest v0.13.9-post.1

Manifest (`bucket/octopus-257.json`, quoted):

```json
"version": "0.13.8-post.1",
"url": "https://github.com/gdm257/octopus/releases/download/v0.13.8-post.1/octopus-windows-amd64.zip",
"checkver": {
    "github": "https://github.com/gdm257/octopus",
    "regex": "releases/tag/v([\\w.-]+)"
},
"autoupdate": { "architecture": { "64bit": {
    "url": "https://github.com/gdm257/octopus/releases/download/v$version/octopus-windows-amd64.zip" } } }
```

### Confirmed facts

- `gdm257/octopus` releases (newest first, from releases.atom + releases pages): **v0.13.9-post.1**, v0.13.8-post.1, v0.13.6-post.1, v0.13.4-post.1, v0.13.3-post.1, v0.13.2-post.1, v0.13.2, v0.13.1, v0.13.0, v0.12.1. Pattern: `v<semver>` or `v<semver>-post.N`.
- `https://github.com/gdm257/octopus/releases/latest` redirects to `/releases/tag/v0.13.9-post.1` ⇒ v0.13.9-post.1 is the latest **published, non-prerelease, non-draft** release (GitHub's `/releases/latest` excludes prereleases and drafts by definition — no API needed). Authored by github-actions ("ci: bump version to 0.13.9-post.1"), 14 assets.
- **Root cause (source-verified)**: under a GitHub token (excavator CI / local gh auth), scoop switches this checkver to API mode: fetch `api.github.com/repos/gdm257/octopus/releases/latest`, extract `$.tag_name` = `v0.13.9-post.1`, then match the custom regex **against the tag_name string only**. `releases/tag/v([\w.-]+)` cannot match `v0.13.9-post.1` → `couldn't match`. The manifest's regex only ever worked in tokenless HTML mode.
- Do not rely on removing the regex either: scoop's API-mode default `(?:v|V)?([\d.-]+)` captures `0.13.9-` (letter class missing) — broken for `-post.N` tags.

### Proposed fix (regex only; replace the `regex` value, keep the rest)

```json
"checkver": {
    "github": "https://github.com/gdm257/octopus",
    "regex": "v([\\w.-]+)"
}
```

- Against tag_name `v0.13.9-post.1` → captures `0.13.9-post.1` — matches the manifest `version` format exactly, feeds autoupdate `v$version` → `releases/download/v0.13.9-post.1/octopus-windows-amd64.zip` (asset-name pattern unchanged from the working v0.13.8-post.1 release).
- HTML-mode-robust alternative if you want the regex to also survive a tokenless run (unanchored `v([\w.-]+)` could hit stray page text like "viewport" in full-HTML mode): `"regex": "v(\\d+\\.\\d+\\.\\d+(?:-post\\.\\d+)?)"` — matches both bare `v0.13.2` and `v0.13.9-post.1` tags, in API and HTML modes. Both regexes are correct for the excavator (API mode); pick one.

## Caveats / Not verified

- No `gh api` was available (bash gated), so per-release `prerelease` booleans were not read from the API; octopus prerelease status is derived from `/releases/latest` redirect semantics (sound but indirect).
- Ryanjiena/chrome_plus asset file names for release 1.5.4 were not enumerated (page rendered an assets spinner); confirm before re-pointing chrome-plus there.
- `softalk.stars.ne.jp` direct (non-proxy) and CI-runner reachability unverified; the old host failed from two independent vantage points (this environment + CI runner per PRD).
- WinDeckHelper `/tree/v2.3.5` still resolving to the old tree is a GitHub ref-resolution artifact; the tag archive 404 is the authoritative signal that `refs/tags/v2.3.5` is gone.

## Related files

- `.trellis/tasks/10-01-fix-excavator-checkver/prd.md` — task context and failure list
- `bucket/{chrome-plus,WinDeckHelper,softalk,git-ssh-sign,octopus-257}.json` — manifests quoted above (read-only; not modified)
- Scoop checkver semantics: `ScoopInstaller/Scoop` master `bin/checkver.ps1` (fetched 2026-10-01); bucket-local `bin/checkver.ps1` delegates to it
