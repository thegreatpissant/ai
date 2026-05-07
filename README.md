# ai-skills

A Claude Code plugin marketplace. Install plugins from here into any project to
get reusable skills, scripts, and conventions.

## Plugins

### `contributing`

Documentation amendment protocol: base documents are immutable, amendments
accumulate, consolidated views are generated on demand. Ships with a
`generate-consolidated-docs.sh` script that reads amendment frontmatter and
renders merged views into `docs/.consolidated/`.

Once installed, invoke as `/contributing:contributing-protocol`.

## Layout

```
.claude-plugin/
  marketplace.json                            ← catalog (this repo = one marketplace)
plugins/
  contributing/
    .claude-plugin/plugin.json                ← plugin manifest
    skills/contributing/
      SKILL.md                                ← skill definition
      scripts/generate-consolidated-docs.sh   ← invoked via ${CLAUDE_SKILL_DIR}
```

## Install in any project

From a local checkout (useful while iterating):

```
/plugin marketplace add /your/local/checkout/ai
/plugin install contributing@ai-skills
```

From the git remote (once pushed):

```
/plugin marketplace add https://github.com/thegreatpissant/ai.git
/plugin install contributing@ai-skills
```

Pull updates later with:

```
/plugin marketplace update ai-skills
```

## Adding another plugin

1. Create `plugins/<name>/.claude-plugin/plugin.json` with `name`,
   `description`, `version`.
2. Add skills under `plugins/<name>/skills/<skill-name>/SKILL.md`. Reference
   bundled scripts via `${CLAUDE_SKILL_DIR}/...` so paths resolve from the
   plugin cache.
3. Append a new entry to the `plugins` array in
   `.claude-plugin/marketplace.json`:

   ```json
   {
     "name": "<name>",
     "source": "./plugins/<name>",
     "description": "..."
   }
   ```

4. Commit and push. Existing installs pick up the new plugin on the next
   `/plugin marketplace update ai-skills`.

## Notes on other agents

The `.claude-plugin/` packaging is Claude-Code-specific. Running Claude Code
inside a VS Code fork (e.g. Antigravity) loads these plugins normally, since
Claude Code manages its own plugin system regardless of the host IDE. Other
agents (Antigravity's native Gemini agent, etc.) won't read `SKILL.md` or
resolve `${CLAUDE_SKILL_DIR}` — the conventions themselves are portable, but
the packaging isn't.
