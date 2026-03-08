# Release Workflow

StateObservationKit separates `develop` as the integration branch and `main` as the release branch, with `VERSION` acting as the single source of truth for release tags. The branch strategy follows the same model.

## Branch Strategy

| Branch / Prefix | Role | Rules |
| --- | --- | --- |
| `develop` | default branch / integration branch | The main development baseline. Most pull requests should target this branch. |
| `feature/release-x.y.z` | stable release train branch | Cut from `develop` for a stable train and set `VERSION=x.y.z`. |
| `feature/release-x.y.z-beta.n` | prerelease train branch | Use for beta or prerelease trains and set `VERSION=x.y.z-beta.n`. |
| `feature/<topic>` / `fix/<topic>` / `docs/<topic>` | work branch | Regular work branches that can be cut from a release train branch. Do not reuse the `feature/release-...` prefix for them. |
| `main` | release branch | Accept only pull request merges from `develop`, and let the workflow release only pushes that are tied to a merged pull request. |

## Branch Roles

| Branch | Role | Rules |
| --- | --- | --- |
| `develop` | default branch / integration branch | The day-to-day baseline. `ci.yml` and `format.yml` run for pushes and pull requests targeting this branch, and this is the final validation stage. |
| `feature/release-x.y.z` / `feature/release-x.y.z-beta.n` | release train branch | Create it from `develop` and keep the branch suffix aligned with `VERSION`. `ci.yml` and `format.yml` also run for pull requests into these branches and for pushes after merges, including version-alignment checks. |
| `main` | release branch | Accept only pull request merges from `develop`; after merge, `release-tag.yml` creates tags only for commits tied to a merged pull request. |

Existing tags use the `0.3.1` style without a `v` prefix, so this workflow keeps that format.

## VERSION Rules

- The release version lives in the repository-root `VERSION` file.
- `VERSION` must use `MAJOR.MINOR.PATCH` or `MAJOR.MINOR.PATCH-prerelease`.
- `feature/release-x.y.z` and `feature/release-x.y.z-beta.n` branches must keep the branch suffix aligned with `VERSION`.
- A merge into `main` creates a new annotated tag when `VERSION` differs from the previous `main` revision, or when `VERSION` is newly introduced and the same tag does not already exist.
- Prerelease labels such as `1.4.0-beta.1` are valid and are published as-is.

## Recommended Flow

1. Create `feature/release-x.y.z` for a stable train, or `feature/release-x.y.z-beta.n` for a prerelease train, from `develop`.
2. Update `VERSION` to the target release number on that release train branch.
3. Branch feature or fix work from the release train branch using regular names such as `feature/<topic>` or `fix/<topic>`, then merge those branches back into the release train branch.
4. Merge the release train branch into `develop` and use CI / format / review on `develop` as the final validation stage.
5. When `develop` is green, open and merge a `develop -> main` pull request.
6. After the merge into `main`, `release-tag.yml` detects the `VERSION` change and creates the matching tag if it does not already exist.

## Beta / Pre-release Outlook

- A prerelease `VERSION` works with the same automation path.
- For example, pull-request merging `VERSION=1.4.0-beta.1` into `main` creates the `1.4.0-beta.1` tag.
- To move from beta to stable, bump `VERSION` to `1.4.0` and repeat the `develop -> main` release step.
- If you later need a separate beta publishing channel, keeping prereleases in SemVer form now makes it straightforward to split that logic into a dedicated workflow.

## GitHub Settings

To make this workflow effective, configure GitHub with:

- `develop` as the default branch
- protected branches for both `develop` and `main`
- no direct pushes to `main`, only pull request merges

This keeps the "validate on `develop`, release from `main`" path enforced both operationally and through automation.
