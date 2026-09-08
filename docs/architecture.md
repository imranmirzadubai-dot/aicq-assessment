# AICQ Architecture

## System of record

Supabase is the current backend and database system for AICQ.

The GitHub repository contains source code, database definitions, migrations,
configuration templates, and documentation. Production participant data and
secrets must never be committed to this public repository.

## Core assessment flow

1. Create participant attempt
2. Resolve the frozen assessment/form versions
3. Generate and persist presentation/randomization state
4. Present assessment items
5. Record responses
6. Record confidence signals
7. Capture practical evidence where applicable
8. Submit the attempt
9. Score server-side
10. Generate interpretation/development outputs
11. Generate/release the assessment report

## Security principle

Answer keys, scoring logic, attempt state, and authoritative assessment state
must remain server-side. The client is not trusted to determine correctness
or final scores.
