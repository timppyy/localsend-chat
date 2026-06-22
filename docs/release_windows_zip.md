# Windows Release ZIP

This repository publishes the Windows desktop build as a GitHub Release Asset.
Use the `Release Windows ZIP` workflow for chat release zips.

## What This Workflow Does

- Checks out the requested tag, branch, or commit.
- Installs Flutter `3.38.10`.
- Runs `flutter pub get` in `common/`, `app/`, and `app/rust_builder/cargokit/build_tool/`.
- Runs build generation in `common/` and `app/`.
- Runs chat-focused tests and scoped analyze when `run_verification` is true.
- Builds the Windows app with `flutter build windows`.
- Adds `settings.json` and the required Visual C++ runtime DLLs to the release folder.
- Creates `LocalSendChat-<tag>-windows-x64.zip`.
- Uploads the zip as a workflow artifact.
- Creates or updates the GitHub Release and uploads the zip as a Release Asset.

## Tag-Based Release

Use this when the commit is ready and should become the next release.

```powershell
git tag -a v1.17.0-chat.N -m "Release v1.17.0-chat.N" HEAD
git push origin v1.17.0-chat.N
```

The tag push triggers `.github/workflows/release_windows_zip.yml` automatically
because it matches `v*-chat.*`.

## Manual Release

Use this when you want to trigger or rerun the release from GitHub.

1. Open GitHub.
2. Go to `Actions`.
3. Select `Release Windows ZIP`.
4. Click `Run workflow`.
5. Fill in:

```text
tag_name: v1.17.0-chat.N
ref_to_build: v1.17.0-chat.N
release_name: LocalSend Chat v1.17.0-chat.N
run_verification: true
```

## Validation

After the workflow finishes, verify:

- The workflow run conclusion is success.
- The GitHub Release exists for `v1.17.0-chat.N`.
- The Release `Assets` section contains `LocalSendChat-v1.17.0-chat.N-windows-x64.zip`.
- The asset uploader is `github-actions[bot]`.
- The Release body includes the SHA256 hash.

Do not treat a raw GitHub link to a zip committed under `app/` as a completed
release. The zip must be uploaded as a GitHub Release Asset.

## Verified Reference Run

- Workflow: `Release Windows ZIP`
- Run: `https://github.com/timppyy/localsend-chat/actions/runs/27928481138`
- Tag: `v1.17.0-chat.6`
- Asset: `LocalSendChat-v1.17.0-chat.6-windows-x64.zip`
- Asset URL: `https://github.com/timppyy/localsend-chat/releases/download/v1.17.0-chat.6/LocalSendChat-v1.17.0-chat.6-windows-x64.zip`
- Asset SHA256: `58cf680e22391db78a3e15c59dbeaa7882796c2c0b16027b45b15a7610ddaed7`

## Notes

- Keep release zip files out of git history.
- Keep the workflow on the default branch so GitHub exposes the manual trigger.
- Use `run_verification: true` for normal releases.
- Use `run_verification: false` only for a deliberate packaging-only rerun after
  a verified commit.
