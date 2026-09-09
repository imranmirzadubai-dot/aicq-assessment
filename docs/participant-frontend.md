# AICQ Participant Frontend

The AICQ Participant Frontend is a modern, responsive, standalone participant assessment web application that integrates seamlessly with the existing Cloudflare Worker v1.9 API and Supabase backend contracts.

## Architecture & Features

1. **Assessment Entry & Session Initialization**: 
   - Supports creating assessment attempts via `POST /v1/attempts` with participant ID, assessment ID, program ID, and organization ID.
   - Securely receives and stores the opaque participant session token (`session_token`) for subsequent attempt-scoped operations.

2. **Attempt Lifecycle & Lobby**:
   - Displays session status and allows participants to officially start their timed/tracked attempt via `POST /v1/attempts/:id/start`.

3. **Question Item Runner**:
   - Renders questions sequentially from position 1 to 32 via `GET /v1/attempts/:id/items/:position`.
   - Supports randomized option display (`option_order`) and tracks presentation sequences.

4. **Response Capture & Confidence Rating**:
   - Records multiple-choice selections, skips, and response times via `POST /v1/attempts/:id/responses`.
   - Captures participant confidence ratings (1 to 5) via `POST /v1/attempts/:id/confidence`.
   - Validates client payloads against forbidden tampering fields (such as `correct`, `is_correct`, `score`).

5. **Practical-Task Presentation & Evidence Capture**:
   - Captures ordered practical solution steps and submission payloads via `POST /v1/attempts/:id/practical`.

6. **Final Submission & Result Retrieval**:
   - Submits the completed attempt with required `Idempotency-Key` header and request hash via `POST /v1/attempts/:id/submit`.
   - Retrieves and displays final scoring, competency breakdowns, and certificate status via `GET /v1/attempts/:id/result`.

## Local Development & Setup

1. Serve the `src/participant-frontend/index.html` file using any static file server (e.g., Python HTTP server or Live Server):
   ```bash
   python3 -m http.server 8080 --directory src/participant-frontend
   ```
2. Open `http://localhost:8080` in your browser.
3. Configure your Worker API Base URL (defaults to production Worker endpoint) and provide valid participant and assessment UUIDs.
