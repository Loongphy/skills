# skills

A collection of reusable AI agent skills.

## exa-search

Search the web and extract page content via the [Exa API](https://exa.ai/docs/reference/search). Includes a cross-platform CLI with subcommands for search, content extraction, and LLM-powered answers:
- **Unix**: [`exa`](./exa-search/exa) (bash)
- **Windows**: [`exa.ps1`](./exa-search/exa.ps1) (PowerShell 5.1+)

An API key is required. Get one at [Exa Dashboard](https://dashboard.exa.ai/api-keys), then set it via either:
- **Environment variable**: `export EXA_API_KEY=<your-key>` (Unix) or `$env:EXA_API_KEY=<your-key>` (Windows)
- **Config file**: `echo <your-key> > ~/.config/exa-api-key` (Unix) or `$HOME\.config\exa-api-key` (Windows)

See [exa-search/SKILL.md](./exa-search/SKILL.md) for usage and flags.
