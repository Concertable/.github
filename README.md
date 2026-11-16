# .github

Account-wide defaults for Concertable repositories.

`.agents/github-access.json` turns on the tomjseery-bot GitHub App for agents in every Concertable repository, through the tj-agents GitHub access gate. A repository overrides it by committing its own `.agents/github-access.json`, for example `{"schema_version": 1, "method": "human"}`. Delete this file to turn the bot off for the whole account.
