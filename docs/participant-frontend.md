# AICQ Participant Frontend

The AICQ Participant Frontend is a clean, responsive single-page web application designed for participants taking professional AICQ assessments. It interacts directly with the Cloudflare Worker API (`src/index.js`) and Supabase backend contracts without exposing administrative privileges or sensitive server keys.

## Features

1. **Participant Entry & Attempt Creation**: Collects participant demographic details (name, age, gender, occupation, experience) and initializes an attempt using `aicq_api_create_attempt_v1`, securely provisioning a session token.
2. **Attempt Session Lifecycle & Security**: Uses secure session bearer tokens (`Bearer <session_token>`) stored client-side for all authorized requests (`/v1/attempts/:id/...`).
3. **Assessment & Question Rendering**: Dynamically renders knowledge items, multiple-choice options, and practical task instructions retrieved via `/v1/attempts/:id`.
4. **Response & Confidence Capture**: Automatically persists answers (`/v1/attempts/:id/responses`) and confidence ratings (`/v1/attempts/:id/confidence`) on user selection.
5. **Practical Task Submission**: Captures ordered steps and custom submission data (`/v1/attempts/:id/practical`).
6. **Attempt Submission & Result Retrieval**: Enforces idempotency via the `Idempotency-Key` header during submission (`/v1/attempts/:id/submit`) and displays final scoring metrics via `/v1/attempts/:id/result`.
7. **Error & Retry Handling**: Provides user-friendly error banners and clean session management.

## Local Development & Setup

1. **Configure Environment**: Ensure your Cloudflare Worker environment and Supabase instance are running.
2. **Serve Frontend**:
   You can serve `src/index.html` via any static file server or integrate it into the Cloudflare Worker static asset binding.
   ```bash
   npx serve src
   ```
3. **API Integration**:
   By default, the frontend connects to `window.location.origin`. For local development against a local worker, configure the API base URL in `src/index.html` if running on a separate port.
