# Consuming the organization workflows

Consumer repositories call these workflows from thin repository-owned workflows. Pin every call to a full
commit SHA; Renovate updates that SHA after the consumer's own CI passes.

```yaml
jobs:
  dotnet:
    uses: Concertable/.github/.github/workflows/dotnet-ci.yml@<full-commit-sha>
    with:
      solution: Concertable.Auth.slnx
    permissions:
      contents: read
      packages: read
```

The caller owns triggers, path selection, service-specific validation, environments, and the final
`ci-complete` aggregation job. Publication callers pass `publish: false` in pull requests and may set it to
`true` only from their protected release flow. The reusable workflow declares the maximum permissions it
needs; callers should grant only those permissions for the selected mode.

Available contracts:

- `dotnet-ci.yml`: restore, Release build, and optional tests for one solution or project.
- `node-ci.yml`: clean npm install followed by selected lint, typecheck, test, and build scripts.
- `nuget-publish.yml`: pack, attest, optionally publish, and retain NuGet packages.
- `npm-publish.yml`: install/test, pack, clean-consumer install, attest, and optionally publish one npm package.
- `container-publish.yml`: BuildKit build, critical-vulnerability scan, SBOM/provenance, keyless signing, and optional GHCR push.
- `apphost-smoke.yml`: restore/build an AppHost and require a health endpoint before timeout.
- `terraform-ci.yml`: recursive formatting, backend-free initialization, validation, and optional plan.

`repository-settings/` contains API payload templates. Apply them only after substituting repository-specific
reviewers, environments, and required checks, then compare the returned GitHub object with the intended
payload. The templates contain no secret values.
