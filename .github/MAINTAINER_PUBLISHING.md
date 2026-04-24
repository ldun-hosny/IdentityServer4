# Maintainer Package Publishing

This repository has a GitHub Actions workflow at `.github/workflows/publish.yml` that publishes NuGet packages.

## Visibility and access

- The workflow file is public because this is a public repository.
- Publishing is still restricted by GitHub permissions and repository secrets.
- Do not put private credentials or internal-only instructions in tracked files.

## Safe maintainer process

1. Trigger the `Publish NuGet Packages` workflow from a signed tag (`v*`) or by `workflow_dispatch`.
2. Provide the version input when using manual dispatch.
3. Ensure `NUGET_API_KEY` is configured in repository secrets.
4. Verify publish artifacts on the corresponding GitHub Release.

## Private notes

If you need personal/internal notes, keep them in a local file that is not tracked by git, for example:

- `docs/maintainers/publish.local.md` (ignored via `.git/info/exclude` on your machine)

