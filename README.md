# .github

Account-wide defaults for Concertable repositories.

`.agents/github-access.json` turns on the tomjseery-bot GitHub App for agents in every Concertable repository, through the tj-agents GitHub access gate. A repository overrides it by committing its own `.agents/github-access.json`, for example `{"schema_version": 1, "method": "human"}`. Delete this file to turn the bot off for the whole account.

`.github/merge-policy.json` is the default merge policy for every Concertable repository without its own: no approval, agents may merge once the required checks pass, and nobody pushes to the default branch outside a pull request. A repository overrides it entirely by committing its own `.github/merge-policy.json`. The schema is [github-actions:merge-policy](https://github.com/tj-agents/github-actions/blob/main/.agents/github-actions/utility/merge-policy/SKILL.md), and tj-agents/github's `github:configuration` applies it.
