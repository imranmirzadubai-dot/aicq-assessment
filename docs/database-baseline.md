# AICQ Database Baseline

Generated from the connected AICQ Supabase project.

## Main domains

- Assessment definitions and versions
- Forms and form versions
- Items and item versions
- Item options
- Competencies and sub-competencies
- Attempts and participant sessions
- Responses and response presentations
- Confidence responses
- Practical tasks, submissions and evidence
- Evidence and competency results
- Scoring versions
- Interpretations
- Development plans/actions
- Reports and report templates
- Organizations and user profiles
- Audit logging
- Version registry
- Import/jobs/idempotency infrastructure

## Important RPC/API surface

The database currently exposes server-side operations for:

- attempt creation/start/submission
- participant sessions
- item retrieval
- response capture
- confidence capture
- practical submission/scoring
- assessment scoring
- evidence/result retrieval
- assessment/form publication and validation
- frozen question-bank import/validation
- audit writing
- admin checks

The database remains the authoritative source for assessment state and scoring.
