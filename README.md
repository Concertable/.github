# Concertable organization defaults

This repository owns Concertable's organization-wide reusable GitHub Actions workflows, repository-policy
templates, Renovate preset, and default community health files.

Call reusable workflows by immutable commit SHA. Consumer repositories keep thin trigger workflows and a
repository-local `ci-complete` job; they do not copy the shared implementation.

See [the consumer contracts](docs/CONSUMING_WORKFLOWS.md) before adopting a workflow or policy template.
