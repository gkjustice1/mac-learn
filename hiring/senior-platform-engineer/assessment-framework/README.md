# MEKOS Engineering Assessment Framework

Purpose: evaluate engineering candidates using sanitized replicas of real MEKOS delivery stories rather than generic coding exercises.

## Principles

1. Every assessment originates from a real MEKOS engineering story.
2. Candidate repositories contain synthetic data only; never production secrets, student data, customer data, or proprietary Master Blueprint content.
3. Seeded defects must represent realistic failure modes from the source story.
4. Candidates are scored on evidence-driven delivery: inspect -> isolate -> fix -> test -> verify -> document.
5. Candidate-facing materials never include evaluator answer keys or scoring thresholds.
6. Assessments are versioned and retired when they no longer reflect the current platform architecture.

## Standard Package

Each assessment contains:

- `candidate/README.md` — scenario, constraints, deliverables, submission instructions.
- `internal/evaluator-guide.md` — seeded defect map, acceptable solutions, red flags, follow-up questions.
- `internal/scoring-rubric.md` — standardized scoring and hiring bands.
- `internal/definition-of-done.md` — acceptance checklist.
- `story-source.md` — source story, sanitization notes, competencies measured, version history.

## Current Assessment

`S1-001.4 — Repository REST/GraphQL API & CI Recovery`

This assessment measures TypeScript, REST, GraphQL, PostgreSQL, automated testing, Git/GitHub, GitHub Actions, CI debugging, and Definition of Done discipline.
