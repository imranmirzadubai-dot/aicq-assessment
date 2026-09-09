# AICQ Participant Frontend

The AICQ Participant Frontend is a modern, responsive Single Page Application (SPA) built with React and Vite, integrated seamlessly with the Cloudflare Worker API gateway (`/v1/*`) and Supabase backend RPC contracts.

## Architecture & Features

1. **Participant Entry & Attempt Initialization (`POST /v1/attempts`)**:
   - Collects participant profile details (Name, Age, Gender, Occupation, Experience) and assessment configuration codes.
   - Creates the attempt record and establishes a secure opaque participant session token.

2. **Attempt Lifecycle & Session Handling (`POST /v1/attempts/:id/start`)**:
   - Automatically initializes attempt timing and state upon entry.

3. **Question Rendering & Navigation (`GET /v1/attempts/:id/items/:position`)**:
   - Renders 32 knowledge items sequentially with progress indication and item code tracking.

4. **Response & Confidence Capture (`POST /v1/attempts/:id/responses`, `POST /v1/attempts/:id/confidence`)**:
   - Captures selected options, response timing, option presentation sequence/order, and participant confidence ratings (1-5 scale) while stripping forbidden client-side fields (such as correct answers or scores).

5. **Practical Task Submission (`POST /v1/attempts/:id/practical`)**:
   - Presents practical task scenario requirements and captures ordered execution steps and submission metadata.

6. **Final Cryptographic Submission (`POST /v1/attempts/:id/submit`)**:
   - Performs idempotent submission with an `Idempotency-Key` header and request hash generation.

7. **Result Retrieval (`GET /v1/attempts/:id/result`)**:
   - Displays final scoring and attempt status upon successful completion.

## Local Development & Setup

1. Install dependencies:
   ```bash
   npm install
   ```

2. Run local development server:
   ```bash
   npm run dev
   ```

3. Build for production:
   ```bash
   npm run build
   ```
