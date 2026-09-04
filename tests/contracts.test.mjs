import assert from 'node:assert/strict'
import { readFileSync, readdirSync } from 'node:fs'
import test from 'node:test'

const workflowsDirectory = new URL('../.github/workflows/', import.meta.url)
const workflowNames = readdirSync(workflowsDirectory).filter((name) => name.endsWith('.yml'))
const reusableNames = workflowNames.filter((name) => name !== 'ci.yml')

test('the checkpoint exposes every required reusable workflow', () => {
  assert.deepEqual(reusableNames.sort(), [
    'apphost-smoke.yml',
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
