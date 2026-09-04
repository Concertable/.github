# Compatibility and configuration manifest contracts

All documents are JSON with `schemaVersion: 1`. A system compatibility manifest contains `qualification`
(`commit`, `runUrl`), non-empty canonical `images` references
`ghcr.io/concertable/<image>:<immutable-semver>@sha256:<digest>`, and canonical `packages` references
`<nuget|npm>:<package-name>@<version>`.

An environment manifest contains `environment`, `compatibility.commit`, and the exact promoted `images`.
Its paired App Configuration file is an array of keyed entries containing exactly one of `value` or
`keyVaultReference`. Secret-like keys may only use an HTTPS Key Vault reference; secret values never enter
Git.

A promotion document contains `environment`, `compatibilityCommit`, `rollbackManifest`, and the exact ordered
steps `verify-infrastructure`, `migrate`, `rollout`, `health`, `smoke`. A rollback document names the same
environment, a 40-character `targetCompatibilityCommit`, a non-empty operator reason, and a runbook link.

Renovate reads package versions and image digests directly from those canonical strings, so JSON key ordering
cannot hide a dependency. The tag is the immutable release channel Renovate advances; the digest is the exact
artifact that qualification and deployment consume.
