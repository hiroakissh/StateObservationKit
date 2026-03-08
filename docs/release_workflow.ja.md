# Release Workflow

StateObservationKit の release governance は、`develop` を統合ブランチ、`main` を release ブランチとして分離し、`VERSION` を release tag の single source of truth として扱います。branch strategy もこの前提に揃えます。

## Branch Strategy

| Branch / Prefix | Role | Rules |
| --- | --- | --- |
| `develop` | default branch / integration branch | 日常開発の基準線です。PR の受け口を基本的にここへ集約します。 |
| `feature/release-x.y.z` | stable release train branch | `develop` から切る stable release train 本体です。`VERSION=x.y.z` に更新します。 |
| `feature/release-x.y.z-beta.n` | prerelease train branch | beta などの prerelease を扱う release train です。`VERSION=x.y.z-beta.n` に更新します。 |
| `feature/<topic>` / `fix/<topic>` / `docs/<topic>` | work branch | release train branch から派生してよい通常作業ブランチです。release train と区別するため、`feature/release-...` は使いません。 |
| `main` | release branch | `develop` からの PR merge のみ受け付け、merge 後に tag を作成します。 |

## Branch Roles

| Branch | Role | Rules |
| --- | --- | --- |
| `develop` | default branch / integration branch | 日常開発の基準線。`ci.yml` と `format.yml` はこのブランチへの push / PR を基準に実行し、最終確認の場所として扱います。 |
| `feature/release-x.y.z` / `feature/release-x.y.z-beta.n` | release train branch | `develop` から作成し、branch suffix と `VERSION` を一致させます。通常作業ブランチから戻す PR と merge 後の push に対して `ci.yml` / `format.yml` が動き、release branch との version 整合も確認します。 |
| `main` | release branch | `develop` からの PR merge のみ受け付け、merge 後に `release-tag.yml` が release tag を作成します。 |

既存の tag が `0.3.1` のように `v` なしなので、今後も同じ形式を維持します。

## VERSION Rules

- release version は repo 直下の `VERSION` ファイルで管理します。
- `VERSION` は `MAJOR.MINOR.PATCH` または `MAJOR.MINOR.PATCH-prerelease` 形式を使います。
- `feature/release-x.y.z` と `feature/release-x.y.z-beta.n` では、branch suffix と `VERSION` を一致させます。
- `main` merge 時に `VERSION` が前回の `main` と異なる場合だけ、新しい annotated tag を作成します。
- beta のような prerelease も `VERSION` にそのまま表現します。例: `1.4.0-beta.1`

## Recommended Flow

1. `develop` から stable なら `feature/release-x.y.z`、beta なら `feature/release-x.y.z-beta.n` を作成します。
2. release train branch 上で `VERSION` を対象 version に更新します。
3. 必要な追加機能や修正は release train branch から `feature/<topic>` や `fix/<topic>` を切り、最終的に release train branch へ戻します。
4. release train branch を `develop` に merge し、`develop` 上の CI / format / review で最終確認します。
5. 問題なければ `develop -> main` の PR を作成して merge します。
6. `main` への merge 後、`release-tag.yml` が `VERSION` の差分を検出し、未発行なら同名 tag を自動作成します。

## Beta / Pre-release Outlook

- prerelease suffix を持つ `VERSION` でも、同じ自動 tag 作成ルールで扱えます。
- たとえば `VERSION=1.4.0-beta.1` を `main` へ merge すれば、tag `1.4.0-beta.1` が作成されます。
- stable 版へ進めるときは `VERSION` を `1.4.0` に更新し、再度 `develop -> main` を通します。
- 将来 beta を `main` と分離した channel で公開したくなっても、SemVer prerelease 形式に揃えておけば別 workflow へ分離しやすくなります。

## GitHub Settings

この運用を成立させるには、GitHub 側でも次を設定してください。

- default branch を `develop` に変更する
- `develop` と `main` を protected branch にする
- `main` への direct push を禁止し、PR merge のみにする

この設定により、「`develop` で検証してから `main` で release する」という流れを CI と運用の両方で固定できます。
