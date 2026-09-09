# AICQ Participant Frontend

The AICQ Participant Frontend is a single-page React application built with Vite and Vanilla CSS, integrated seamlessly with the Cloudflare Worker API (`src/index.js`) and Supabase backend.

## Features

1. **Participant Entry & Authentication:** Captures participant demographic details and initializes assessment attempts via `POST /v1/attempts`, returning a secure, opaque session token stored in memory.
2. **Assessment Lifecycle Management:** Handles attempt start (`POST /v1/attempts/:id/start`), item navigation (`GET /v1/attempts/:id/items/:position`), response recording (`POST /v1/attempts/:id/responses`), and confidence capture (`POST /v1/attempts/:id/confidence`).
3. **Practical Task Submission:** Supports interactive step ordering and rationale capture via `POST /v1/attempts/:id/practical`.
4. **Secure Submission & Result Retrieval:** Submits attempts idempotently with request hashing (`POST /v1/attempts/:id/submit`) and retrieves scoring breakdown and interpretations (`GET /v1/attempts/:id/result`).
5. **Robust Error & Loading States:** Gracefully manages server errors, expired sessions, and loading feedback.

## Local Development & Testing

- **Install dependencies:**
  ```bash
  npm install
  ```
- **Run development server:**
  ```bash
  npm run dev
  ```
- **Run test suite:**
  ```bash
  npm test
  ```
- **Build for production:**
  ```bash
  npm run build
  ```
