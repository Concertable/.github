import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import test from 'node:test'

const workflowsDirectory = new URL('../.github/workflows/', import.meta.url)
const workflowNames = readdirSync(workflowsDirectory).filter((name) => name.endsWith('.yml'))
const reusableNames = workflowNames.filter((name) => name !== 'ci.yml')

test('the repository exposes every required reusable workflow contract', () => {
  assert.deepEqual(reusableNames.sort(), [
    'apphost-smoke.yml',
    'compatibility-manifest.yml',
    'configuration-manifest.yml',
    'configuration-promotion.yml',
    'configuration-rollback.yml',
    'container-publish.yml',
    'dotnet-ci.yml',
    'node-ci.yml',
    'npm-publish.yml',
    'nuget-publish.yml',
    'terraform-ci.yml',
  ])
})

for (const name of reusableNames) {
  test(`${name} is callable and pins every external action`, () => {
    const workflow = readFileSync(new URL(name, workflowsDirectory), 'utf8')
    assert.match(workflow, /workflow_call:/)

    for (const [, reference] of workflow.matchAll(/^\s*-?\s*uses:\s*([^\s#]+).*$/gm)) {
      if (reference.startsWith('./')) continue
      const separator = reference.lastIndexOf('@')
      assert.notEqual(separator, -1, `${reference} has no ref`)
      assert.match(reference.slice(separator + 1), /^[0-9a-f]{40}$/, `${reference} is not SHA-pinned`)
    }
  })
}

test('policy templates and Renovate preset are valid JSON', () => {
  for (const path of [
    '../renovate-config.json',
    '../repository-settings/rulesets/main.json',
    '../repository-settings/rulesets/release-tags.json',
    '../repository-settings/environments/release.json',
    '../repository-settings/teams.json',
  ]) {
    assert.doesNotThrow(() => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8')), path)
  }
})

test('CODEOWNERS routes organization policy to the platform team', () => {
  const codeowners = readFileSync(new URL('../.github/CODEOWNERS', import.meta.url), 'utf8')
  assert.match(codeowners, /^\* @Concertable\/platform-maintainers$/m)
})

test('required CI handles merge queues and emits the ruleset context', () => {
  const workflow = readFileSync(new URL('../.github/workflows/ci.yml', import.meta.url), 'utf8')
  assert.match(workflow, /^\s{2}merge_group:$/m)
  assert.match(workflow, /^\s{4}name: ci-complete$/m)
})

test('the complete durable owner-team roster is declared', () => {
  const teams = JSON.parse(readFileSync(new URL('../repository-settings/teams.json', import.meta.url), 'utf8'))
  assert.deepEqual(teams.map(({slug}) => slug).sort(), [
    'auth-maintainers', 'b2b-maintainers', 'configuration-maintainers', 'customer-maintainers',
    'frontend-platform-maintainers', 'infrastructure-maintainers', 'payment-maintainers',
    'platform-maintainers', 'search-maintainers', 'system-maintainers',
  ])
})

test('Renovate sees package versions and image digests in both manifest owners', () => {
  const config = JSON.parse(readFileSync(new URL('../renovate-config.json', import.meta.url), 'utf8'))
  const compatibility = readFileSync(new URL('../fixtures/compatibility-manifest.json', import.meta.url), 'utf8')
  const environment = readFileSync(new URL('../fixtures/environment-manifest.json', import.meta.url), 'utf8')
  assert.equal(config.customManagers.length, 2)
  assert.ok(config.customManagers.every(({managerFilePatterns}) => managerFilePatterns.some((pattern) => pattern.includes('manifest'))))
  assert.match(compatibility, new RegExp(config.customManagers[0].matchStrings[0]))
  assert.match(compatibility, new RegExp(config.customManagers[1].matchStrings[0]))
  assert.match(environment, new RegExp(config.customManagers[1].matchStrings[0]))
})

test('publication authority is isolated from caller build code', () => {
  for (const name of ['nuget-publish.yml', 'npm-publish.yml', 'container-publish.yml']) {
    const workflow = readFileSync(new URL(name, workflowsDirectory), 'utf8')
    assert.match(workflow, /^\s{2}verify:\n(?:.|\n)*?permissions: \{contents: read, packages: read\}/m)
    assert.match(workflow, /^\s{2}publish:\n(?:.|\n)*?environment: release\n\s+permissions: \{contents: read, packages: write, id-token: write, attestations: write\}/m)
    assert.match(workflow, /inputs\.publish && github\.ref_protected/)
  }
})
