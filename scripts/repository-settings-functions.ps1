function ConvertTo-EnvironmentPolicyInput {
    param([Parameter(Mandatory)][object] $Environment)

    $waitRule = $Environment.protection_rules | Where-Object type -eq 'wait_timer'
    $reviewRule = $Environment.protection_rules | Where-Object type -eq 'required_reviewers'

    [pscustomobject]@{
        wait_timer = if ($waitRule) { $waitRule.wait_timer } else { 0 }
        reviewers = @(
            if ($reviewRule) {
                $reviewRule.reviewers | ForEach-Object {
                    [pscustomobject]@{ type = $_.type; id = $_.reviewer.id }
                }
            }
        )
        deployment_branch_policy = $Environment.deployment_branch_policy
    }
}

function Find-RepositoryTeamPermission {
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]] $TeamPages,
        [Parameter(Mandatory)][string] $Slug
    )

    foreach ($page in $TeamPages) {
        foreach ($team in @($page)) {
            if ($team.slug -eq $Slug) {
                return $team
            }
        }
    }

    return $null
}
