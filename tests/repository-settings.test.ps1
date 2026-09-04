$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot '../scripts/repository-settings-functions.ps1')

function Assert-Equal {
    param([object] $Expected, [object] $Actual, [string] $Message)

    if ($Expected -cne $Actual) {
        throw "$Message Expected '$Expected', found '$Actual'."
    }
}

$withoutReviewers = [pscustomobject]@{
    protection_rules = @([pscustomobject]@{ type = 'branch_policy' })
    deployment_branch_policy = [pscustomobject]@{ protected_branches = $true; custom_branch_policies = $false }
}
$emptyInput = ConvertTo-EnvironmentPolicyInput -Environment $withoutReviewers
Assert-Equal 0 @($emptyInput.reviewers).Count 'An absent reviewer rule must normalize to an empty array.'

$withTeamReviewer = [pscustomobject]@{
    protection_rules = @([pscustomobject]@{
        type = 'required_reviewers'
        reviewers = @([pscustomobject]@{
            type = 'Team'
            reviewer = [pscustomobject]@{ id = 42; name = 'Platform maintainers' }
        })
    })
    deployment_branch_policy = [pscustomobject]@{ protected_branches = $true; custom_branch_policies = $false }
}
$teamInput = ConvertTo-EnvironmentPolicyInput -Environment $withTeamReviewer
Assert-Equal 'Team' $teamInput.reviewers[0].type 'Reviewer type must come from the API wrapper.'
Assert-Equal 42 $teamInput.reviewers[0].id 'Reviewer ID must come from the nested reviewer.'

$teamPages = ConvertFrom-Json @'
[
  [{"slug":"team-1","permission":"pull"}],
  [{"slug":"platform-maintainers","permission":"maintain"}]
]
'@
$permission = Find-RepositoryTeamPermission -TeamPages $teamPages -Slug 'platform-maintainers'
Assert-Equal 'maintain' $permission.permission 'Owner-team lookup must search every API page.'
