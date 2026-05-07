# Documentation Protocol

This file governs how design documents in this directory are created,
amended, and consumed by humans and AI agents. Read it before touching
any file in docs/.

---

## The Core Rule

**Base documents are never edited directly. Amendments only.**

Every file in docs/ that is not an amendment and not a generated
consolidated view is a base document. It represents the design intent
at a specific point in time. Editing it in place destroys that record.

The amendment chain is the project's design memory. Treat it accordingly.

---

## Amendment Convention

### When to write an amendment

Write an amendment when:
- A gap register item is resolved
- A new design decision is ratified
- An existing decision is revised or superseded
- A new capability is added to the vision

Do not write an amendment for speculative or in-progress work.
Amendments are ratified decisions, not working notes.

### Naming

Amendments are numbered in a single unified sequence regardless of
which base document they affect:

```
AMENDMENT-{NNN}-{short-slug}.md
```

Examples:
```
AMENDMENT-001-reasoning-records.md
AMENDMENT-002-agent-provenance.md
AMENDMENT-003-conflict-resolution.md
```

The sequence is global. AMENDMENT-002 may amend a different base
document than AMENDMENT-001. The front matter declares the target.

### Front matter

Every amendment must include front matter declaring:

```markdown
---
amendment: "002"
title: "Short descriptive title"
status: "Proposed | Ratified | Superseded"
targets:
  - "VISION.md"
  - "AI-INTEGRATION-ARCHITECTURE.md"
gap_refs:
  - "GAP-001"
  - "GAP-004"
date: "YYYY-MM-DD"
authors: ["Name", "Name"]
---
```

`targets` lists every base document this amendment affects.
`gap_refs` lists every gap register entry this amendment resolves or touches.
`status` is Proposed until a human explicitly ratifies it.

### Open questions

Every amendment should include an open questions section for decisions
that are intentionally deferred. These must not be resolved silently
by an AI agent — they must be surfaced to the human before implementation.

### Commit message convention

```
AMENDMENT-{NNN}: {short description} [GAP-{N}, GAP-{N}]
```

Example:
```
AMENDMENT-002: agent provenance on graph elements [GAP-001, GAP-004]
```

---

## Consolidated Views

### What they are

A consolidated view is a single rendered document that combines a base
document with all amendments that target it, applied in sequence order.
It is the human-readable and agent-readable current state of the document.

Consolidated views are **build artifacts**. They live in `docs/.consolidated/`
which is in `.gitignore`. They are never committed and never edited directly.

### Generating them

```bash
make docs
```

This regenerates all consolidated views. Run it when:
- You want to review the current state of any document
- You are starting a new AI agent session
- An amendment has been committed and you need the updated view

### Consolidated view header

Every generated consolidated view begins with a header showing its
provenance:

```markdown
---
generated: true
do_not_edit: true
built_from:
  - VISION.md @ {commit_hash}
  - AMENDMENT-001-reasoning-records.md @ {commit_hash}
  - AMENDMENT-002-agent-provenance.md @ {commit_hash}
generated_at: {timestamp}
---
```

The commit hash is the context version token. If the hash of docs/
changes during an agent session, the agent's understanding is stale
and it should regenerate before proceeding.

### If make docs is unavailable

Generate the consolidated view manually by:
1. Reading the base document
2. Running `git log --oneline docs/` to identify amendments in sequence order
3. Reading each amendment that targets this document, in order
4. Producing a merged document that reflects the base plus all amendments

---

## Agent Protocol

### At session start

1. Run `git log --oneline docs/` to see the amendment chain
2. Run `make docs` to regenerate consolidated views
3. Load consolidated views from `docs/.consolidated/` — not source files
4. Note the commit hash in the consolidated view header as your
   context version token
5. Load only documents relevant to the current session's work

### During a session

- If `git log --oneline docs/` shows new commits since session start,
  regenerate and reload affected consolidated views before proceeding
- Do not load the full amendment chain into context — load the
  consolidated view instead
- When an open question is encountered in an amendment, stop and
  surface it to the human. Do not resolve it silently.

### When producing amendments

1. Read the relevant source documents directly (not consolidated views)
   so you are reasoning against the actual source of truth
2. Produce the amendment file with correct front matter
3. Set status to "Proposed" — the human ratifies, not the agent
4. Commit to docs/ with the correct commit message convention
5. Inform the human that ratification is needed before implementation proceeds

---

## Consolidation

Consolidated views are generated continuously. Base documents and their
amendments are consolidated into a new baseline only at deliberate
release boundaries.

Consolidation means:
- All ratified amendments are integrated into a new version of the
  base document
- The old base document and its amendments are archived together as
  a versioned snapshot
- The amendment sequence continues from where it left off

Consolidation is an explicit human-ratified act. It is not triggered
automatically by the number of amendments or the passage of time.

---

## File Structure

Example file structure:  
```
docs/
  VISION.md                              ← base document, never edited
  AI-INTEGRATION-ARCHITECTURE.md         ← base document, never edited
  VISION-GAP-REGISTER-001.md             ← base document, never edited
  AMENDMENT-001-reasoning-records.md     ← amendment, never edited
  AMENDMENT-002-agent-provenance.md      ← amendment, never edited
  CONTRIBUTING.md                        ← this file
  .consolidated/                         ← gitignored, generated output
    VISION-current.md
    AI-INTEGRATION-ARCHITECTURE-current.md
```

---

*This protocol was established April 2026 as part of the intent
capture system described in AMENDMENT-001 and the companion document
Intent as Infrastructure (thegreatpissant.com, April 2026).*
