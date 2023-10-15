# Scoop Bucket 257

[![Tests](https://github.com/gdm257/scoop-257/actions/workflows/ci.yml/badge.svg)](https://github.com/gdm257/scoop-257/actions/workflows/ci.yml) [![Excavator](https://github.com/gdm257/scoop-257/actions/workflows/excavator.yml/badge.svg)](https://github.com/gdm257/scoop-257/actions/workflows/excavator.yml)

Yet another bucket for [Scoop](https://scoop.sh), the Windows command-line installer.

## How do I install these manifests?

After manifests have been committed and pushed, run the following:

```pwsh
scoop bucket add gdm257 https://github.com/gdm257/scoop-257
scoop install gdm257/<manifestname>
```

## How do I contribute new manifests?

To make a new manifest contribution, please read the [Contributing
Guide](https://github.com/ScoopInstaller/.github/blob/main/.github/CONTRIBUTING.md)
and [App Manifests](https://github.com/ScoopInstaller/Scoop/wiki/App-Manifests)
wiki page.
