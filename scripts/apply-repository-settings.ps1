[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^[^/]+/[^/]+$')]
    [string] $Repository,

    [Parameter(Mandatory)]
    [string] $OwnerTeamSlug
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$organization, $repositoryName = $Repository -split '/', 2
$teams = Get-Content -LiteralPath (Join-Path $root 'repository-settings/teams.json') -Raw | ConvertFrom-Json

function Assert-TemplateEqual {
    param([object] $Expected, [object] $Actual, [string] $Path)

    if ($Expected -is [pscustomobject]) {
        foreach ($property in $Expected.PSObject.Properties) {
            $actualProperty = $Actual.PSObject.Properties[$property.Name]
            if (-not $actualProperty) { throw "Missing verified field '$Path.$($property.Name)'." }
            Assert-TemplateEqual $property.Value $actualProperty.Value "$Path.$($property.Name)"
        }
        return
    }
    if ($Expected -is [array]) {
        $actualItems = @($Actual)
        if ($Expected.Count -ne $actualItems.Count) { throw "Array length differs at '$Path'." }
        for ($index = 0; $index -lt $Expected.Count; $index++) {
            Assert-TemplateEqual $Expected[$index] $actualItems[$index] "$Path[$index]"
        }
        return
    }
    if ($Expected -cne $Actual) { throw "Expected '$Expected' but found '$Actual' at '$Path'." }
}

foreach ($team in $teams) {
    $existing = gh api "orgs/$organization/teams/$($team.slug)" 2>$null | ConvertFrom-Json
    if ($LASTEXITCODE -ne 0) {
        $body = @{ name = $team.name; privacy = $team.privacy } | ConvertTo-Json -Compress
        if ($PSCmdlet.ShouldProcess("$organization/$($team.slug)", 'Create organization team')) {
            $created = $body | gh api --method POST "orgs/$organization/teams" --input - | ConvertFrom-Json
            if ($created.slug -ne $team.slug) { throw "Created team slug '$($created.slug)' did not match '$($team.slug)'." }
        }
    }
    elseif ($existing.name -ne $team.name -or $existing.privacy -ne $team.privacy) {
        $body = @{ name = $team.name; privacy = $team.privacy } | ConvertTo-Json -Compress
        if ($PSCmdlet.ShouldProcess("$organization/$($team.slug)", 'Update organization team')) {
            $body | gh api --method PATCH "orgs/$organization/teams/$($team.slug)" --input - | Out-Null
        }
    }
    if (-not $WhatIfPreference) {
        $actualTeam = gh api "orgs/$organization/teams/$($team.slug)" | ConvertFrom-Json
        Assert-TemplateEqual ([pscustomobject]@{ name = $team.name; privacy = $team.privacy }) $actualTeam "team[$($team.slug)]"
    }
}

if ($OwnerTeamSlug -notin $teams.slug) { throw "Unknown owner team '$OwnerTeamSlug'." }
if ($PSCmdlet.ShouldProcess("$OwnerTeamSlug -> $Repository", 'Grant maintain permission')) {
    gh api --method PUT "orgs/$organization/teams/$OwnerTeamSlug/repos/$organization/$repositoryName" -f permission=maintain | Out-Null
}

$environment = Get-Content -LiteralPath (Join-Path $root 'repository-settings/environments/release.json') -Raw
if ($PSCmdlet.ShouldProcess("$Repository/release", 'Apply release environment policy')) {
    $environment | gh api --method PUT "repos/$Repository/environments/release" --input - | Out-Null
}

$rulesetPath = Join-Path $root 'repository-settings/rulesets/main.json'
$ruleset = Get-Content -LiteralPath $rulesetPath -Raw
$rulesets = gh api "repos/$Repository/rulesets" | ConvertFrom-Json
$existingRuleset = $rulesets | Where-Object name -eq 'Main merge queue' | Select-Object -First 1
$method = if ($existingRuleset) { 'PUT' } else { 'POST' }
$endpoint = if ($existingRuleset) { "repos/$Repository/rulesets/$($existingRuleset.id)" } else { "repos/$Repository/rulesets" }
if ($PSCmdlet.ShouldProcess("$Repository/Main merge queue", "$method ruleset")) {
    $ruleset | gh api --method $method $endpoint --input - | Out-Null
}

if (-not $WhatIfPreference) {
    $appliedRuleset = gh api "repos/$Repository/rulesets" | ConvertFrom-Json | Where-Object name -eq 'Main merge queue'
    if (-not $appliedRuleset) { throw 'Main merge queue ruleset was not returned after application.' }
    $actualRuleset = gh api "repos/$Repository/rulesets/$($appliedRuleset.id)" | ConvertFrom-Json
    $expectedRuleset = $ruleset | ConvertFrom-Json
    Assert-TemplateEqual $expectedRuleset $actualRuleset 'ruleset'

    $actualEnvironment = gh api "repos/$Repository/environments/release" | ConvertFrom-Json
    $waitRule = $actualEnvironment.protection_rules | Where-Object type -eq 'wait_timer'
    $reviewRule = $actualEnvironment.protection_rules | Where-Object type -eq 'required_reviewers'
    $actualEnvironmentInput = [pscustomobject]@{
        wait_timer = if ($waitRule) { $waitRule.wait_timer } else { 0 }
        reviewers = @($reviewRule.reviewers | ForEach-Object { [pscustomobject]@{ type = $_.reviewer.type; id = $_.reviewer.id } })
        deployment_branch_policy = $actualEnvironment.deployment_branch_policy
    }
    Assert-TemplateEqual ($environment | ConvertFrom-Json) $actualEnvironmentInput 'environment'

    $permission = gh api "orgs/$organization/teams/$OwnerTeamSlug/repos/$organization/$repositoryName" | ConvertFrom-Json
    if ($permission.role_name -ne 'maintain' -and $permission.permissions.maintain -ne $true) {
        throw "Owner team does not have maintain permission on $Repository."
    }
}

Write-Output "Applied and verified organization policy for $Repository."
