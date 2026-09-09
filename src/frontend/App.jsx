import React, { useState, useEffect } from 'react';

const API_BASE_DEFAULT = "https://aicq-foundation-api.imranmirzadubai.workers.dev";

export default function App() {
  const [apiBase, setApiBase] = useState(() => localStorage.getItem("aicq_api_base") || API_BASE_DEFAULT);
  const [view, setView] = useState("entry"); // entry, assessment, practical, completed, result
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  // Participant & Attempt state
  const [attemptData, setAttemptData] = useState(() => {
    const saved = localStorage.getItem("aicq_attempt");
    return saved ? JSON.parse(saved) : null;
  });
  const [sessionToken, setSessionToken] = useState(() => localStorage.getItem("aicq_session") || "");

  // Form input state for entry
  const [formData, setFormData] = useState({
    assessment_code: "AICQ-P1",
    form_code: "AICQ-P1-F01",
    form_version: "1.0",
    participant_name: "",
    participant_age: "",
    participant_gender: "Prefer not to say",
    participant_occupation: "",
    participant_experience: ""
  });

  // Assessment flow state
  const [currentPosition, setCurrentPosition] = useState(1);
  const [currentItem, setCurrentItem] = useState(null);
  const [selectedOptionId, setSelectedOptionId] = useState("");
  const [confidence, setConfidence] = useState(3);
  const [startTime, setStartTime] = useState(Date.now());

  // Practical task state
  const [practicalTask, setPracticalTask] = useState(null);
  const [orderedSteps, setOrderedSteps] = useState([]);

  // Result state
  const [resultData, setResultData] = useState(null);

  // Sync session storage
  useEffect(() => {
    if (attemptData) {
      localStorage.setItem("aicq_attempt", JSON.stringify(attemptData));
    } else {
      localStorage.removeItem("aicq_attempt");
    }
  }, [attemptData]);

  useEffect(() => {
    if (sessionToken) {
      localStorage.setItem("aicq_session", sessionToken);
    } else {
      localStorage.removeItem("aicq_session");
    }
  }, [sessionToken]);

  useEffect(() => {
    localStorage.setItem("aicq_api_base", apiBase);
  }, [apiBase]);

  // Headers helper
  const getAuthHeaders = () => {
    const headers = { "Content-Type": "application/json" };
    if (sessionToken) {
      headers["Authorization"] = `Bearer ${sessionToken}`;
    }
    return headers;
  };

  // 1. Create Attempt & Session
  const handleStartAssessment = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(`${apiBase}/v1/attempts`, {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          assessment_code: formData.assessment_code,
          form_code: formData.form_code,
          form_version: formData.form_version,
          participant_name: formData.participant_name,
          participant_age: formData.participant_age ? Number(formData.participant_age) : null,
          participant_gender: formData.participant_gender,
          participant_occupation: formData.participant_occupation,
          participant_experience: formData.participant_experience ? Number(formData.participant_experience) : null
        })
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || "Failed to create assessment attempt.");
      }

      setAttemptData(data.attempt);
      setSessionToken(data.session?.session_token || "");

      // Call start attempt API
      await fetch(`${apiBase}/v1/attempts/${data.attempt.attempt_id}/start`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${data.session?.session_token}`
        }
      });

      // Load first item
      setCurrentPosition(1);
      await loadItem(data.attempt.attempt_id, 1, data.session?.session_token);
      setView("assessment");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // 2. Load Item
  const loadItem = async (attemptId, position, token) => {
    setLoading(true);
    setError(null);
    try {
      const authHeader = `Bearer ${token || sessionToken}`;
      const res = await fetch(`${apiBase}/v1/attempts/${attemptId}/items/${position}`, {
        method: "GET",
        headers: {
          "Content-Type": "application/json",
          "Authorization": authHeader
        }
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || "Failed to load assessment item.");
      }

      setCurrentItem(data.item);
      setSelectedOptionId("");
      setConfidence(3);
      setStartTime(Date.now());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // 3. Record Response & Confidence, then navigate
  const handleNextItem = async (isSkipped = false) => {
    if (!currentItem) return;
    setLoading(true);
    setError(null);

    const responseTimeMs = Date.now() - startTime;

    try {
      // Record response
      const resResp = await fetch(`${apiBase}/v1/attempts/${attemptData.attempt_id}/responses`, {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          item_version_id: currentItem.item_version_id,
          selected_option_id: selectedOptionId || null,
          skipped: isSkipped,
          response_time_ms: responseTimeMs,
          presentation_sequence: currentPosition,
          option_order: currentItem.options?.map(o => o.option_id) || []
        })
      });

      const dataResp = await resResp.json();
      if (!resResp.ok || !dataResp.ok) {
        throw new Error(dataResp.error?.message || "Failed to record response.");
      }

      // Record confidence
      const resConf = await fetch(`${apiBase}/v1/attempts/${attemptData.attempt_id}/confidence`, {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          confidence: Number(confidence),
          item_version_id: currentItem.item_version_id
        })
      });

      const dataConf = await resConf.json();
      if (!resConf.ok || !dataConf.ok) {
        throw new Error(dataConf.error?.message || "Failed to record confidence.");
      }

      // Next position or move to practical/complete
      if (currentPosition < 32) {
        const nextPos = currentPosition + 1;
        setCurrentPosition(nextPos);
        await loadItem(attemptData.attempt_id, nextPos, sessionToken);
      } else {
        // Transition to practical task or submit
        setView("practical");
      }
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Submit Practical Task
  const handlePracticalSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const res = await fetch(`${apiBase}/v1/attempts/${attemptData.attempt_id}/practical`, {
        method: "POST",
        headers: getAuthHeaders(),
        body: JSON.stringify({
          task_version_id: null,
          ordered_steps: ["Step A", "Step B", "Step C"],
          submission_data: { notes: "Participant completed practical steps" }
        })
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || "Failed to submit practical task.");
      }

      setView("completed");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  // Final Submit Attempt
  const handleFinalSubmit = async () => {
    setLoading(true);
    setError(null);

    try {
      const idempotencyKey = `sub_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
      const res = await fetch(`${apiBase}/v1/attempts/${attemptData.attempt_id}/submit`, {
        method: "POST",
        headers: {
          ...getAuthHeaders(),
          "Idempotency-Key": idempotencyKey
        },
        body: JSON.stringify({ submitted_at: new Date().toISOString() })
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || "Failed to submit attempt.");
      }

      // Fetch results
      const resRes = await fetch(`${apiBase}/v1/attempts/${attemptData.attempt_id}/result`, {
        method: "GET",
        headers: getAuthHeaders()
      });
      const dataRes = await resRes.json();
      if (resRes.ok && dataRes.ok) {
        setResultData(dataRes.result);
      }

      setView("result");
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div>
      <header className="app-header">
        <div className="brand">
          AICQ Assessment Platform <span>Participant Portal</span>
        </div>
        <div style={{ fontSize: "0.85rem", color: "var(--text-muted)" }}>
          {attemptData ? `Attempt: ${attemptData.attempt_id.substring(0, 8)}...` : "Not Started"}
        </div>
      </header>

      <main className="container">
        {error && <div className="error-banner"><strong>Error:</strong> {error}</div>}

        {/* 1. ENTRY VIEW */}
        {view === "entry" && (
          <div className="card">
            <h1>Start Assessment</h1>
            <p>Enter your professional details to begin your AICQ certified assessment session.</p>

            <form onSubmit={handleStartAssessment}>
              <div className="form-group">
                <label>API Gateway Endpoint</label>
                <input
                  type="text"
                  value={apiBase}
                  onChange={e => setApiBase(e.target.value)}
                  required
                />
              </div>

              <div className="form-group">
                <label>Assessment Code</label>
                <input
                  type="text"
                  value={formData.assessment_code}
                  onChange={e => setFormData({...formData, assessment_code: e.target.value})}
                  required
                />
              </div>

              <div className="form-group">
                <label>Full Name</label>
                <input
                  type="text"
                  value={formData.participant_name}
                  onChange={e => setFormData({...formData, participant_name: e.target.value})}
                  placeholder="Jane Doe"
                  required
                />
              </div>

              <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: "1rem" }}>
                <div className="form-group">
                  <label>Age</label>
                  <input
                    type="number"
                    value={formData.participant_age}
                    onChange={e => setFormData({...formData, participant_age: e.target.value})}
                    placeholder="30"
                  />
                </div>
                <div className="form-group">
                  <label>Gender</label>
                  <select
                    value={formData.participant_gender}
                    onChange={e => setFormData({...formData, participant_gender: e.target.value})}
                  >
                    <option>Female</option>
                    <option>Male</option>
                    <option>Non-binary</option>
                    <option>Prefer not to say</option>
                  </select>
                </div>
              </div>

              <div className="form-group">
                <label>Occupation</label>
                <input
                  type="text"
                  value={formData.participant_occupation}
                  onChange={e => setFormData({...formData, participant_occupation: e.target.value})}
                  placeholder="Software Engineer"
                />
              </div>

              <div className="form-group">
                <label>Years of Experience</label>
                <input
                  type="number"
                  value={formData.participant_experience}
                  onChange={e => setFormData({...formData, participant_experience: e.target.value})}
                  placeholder="5"
                />
              </div>

              <button type="submit" className="btn" disabled={loading}>
                {loading ? "Initializing..." : "Begin Assessment"}
              </button>
            </form>
          </div>
        )}

        {/* 2. ASSESSMENT VIEW */}
        {view === "assessment" && currentItem && (
          <div className="card">
            <div style={{ display: "flex", justifyContent: "space-between", alignItems: "center", marginBottom: "1rem" }}>
              <span className="badge badge-info">Question {currentPosition} of 32</span>
              <span style={{ fontSize: "0.85rem", color: "var(--text-muted)" }}>Item Code: {currentItem.item_code}</span>
            </div>

            <div className="progress-bar-container">
              <div className="progress-bar-fill" style={{ width: `${(currentPosition / 32) * 100}%` }}></div>
            </div>

            <h2 style={{ fontSize: "1.2rem", fontWeight: "600", marginBottom: "1.5rem" }}>
              {currentItem.stem}
            </h2>

            <div style={{ marginBottom: "2rem" }}>
              {currentItem.options?.map((opt, idx) => (
                <label
                  key={opt.option_id}
                  className={`option-card ${selectedOptionId === opt.option_id ? "selected" : ""}`}
                >
                  <input
                    type="radio"
                    name="assessment_option"
                    value={opt.option_id}
                    checked={selectedOptionId === opt.option_id}
                    onChange={() => setSelectedOptionId(opt.option_id)}
                  />
                  <div>
                    <strong>{String.fromCharCode(65 + idx)}.</strong> {opt.option_text}
                  </div>
                </label>
              ))}
            </div>

            <div className="form-group" style={{ background: "#f8fafc", padding: "1rem", borderRadius: "8px", border: "1px solid var(--border)" }}>
              <label style={{ marginBottom: "0.25rem" }}>Confidence Level (1 to 5): <strong>{confidence}</strong></label>
              <p style={{ fontSize: "0.8rem", marginBottom: "0.75rem" }}>How confident are you in your answer?</p>
              <input
                type="range"
                min="1"
                max="5"
                step="1"
                value={confidence}
                onChange={e => setConfidence(e.target.value)}
                style={{ cursor: "pointer" }}
              />
              <div style={{ display: "flex", justifyContent: "space-between", fontSize: "0.75rem", color: "var(--text-muted)", marginTop: "0.25rem" }}>
                <span>1 - Guess</span>
                <span>3 - Moderate</span>
                <span>5 - Certain</span>
              </div>
            </div>

            <div className="nav-bar">
              <button
                type="button"
                className="btn btn-secondary"
                onClick={() => handleNextItem(true)}
                disabled={loading}
              >
                Skip Question
              </button>
              <button
                type="button"
                className="btn"
                onClick={() => handleNextItem(false)}
                disabled={loading || !selectedOptionId}
              >
                {loading ? "Saving..." : (currentPosition === 32 ? "Finish Knowledge Section" : "Next Question")}
              </button>
            </div>
          </div>
        )}

        {/* 3. PRACTICAL TASK VIEW */}
        {view === "practical" && (
          <div className="card">
            <h1>Practical Task Submission</h1>
            <p>Review the practical task requirements and submit your solution steps.</p>

            <div style={{ background: "#f8fafc", padding: "1rem", borderRadius: "8px", border: "1px solid var(--border)", marginBottom: "1.5rem" }}>
              <h3 style={{ fontSize: "1rem", marginBottom: "0.5rem" }}>Task Scenario</h3>
              <p style={{ fontSize: "0.9rem", margin: 0 }}>
                Analyze the provided architecture and arrange the deployment steps in the correct secure sequence.
              </p>
            </div>

            <form onSubmit={handlePracticalSubmit}>
              <div className="form-group">
                <label>Ordered Execution Steps</label>
                <div className="step-item">
                  <span>1. Configure secure environment variables & secrets</span>
                  <span className="badge badge-success">Ready</span>
                </div>
                <div className="step-item">
                  <span>2. Run Supabase schema migrations & RPC verification</span>
                  <span className="badge badge-success">Ready</span>
                </div>
                <div className="step-item">
                  <span>3. Deploy Cloudflare Worker API gateway</span>
                  <span className="badge badge-success">Ready</span>
                </div>
              </div>

              <button type="submit" className="btn" disabled={loading}>
                {loading ? "Submitting Practical..." : "Submit Practical Task"}
              </button>
            </form>
          </div>
        )}

        {/* 4. COMPLETED / READY TO SUBMIT */}
        {view === "completed" && (
          <div className="card" style={{ textAlign: "center" }}>
            <h1>Assessment Completed</h1>
            <p>You have successfully completed all knowledge items and practical tasks for this session.</p>

            <div className="success-banner" style={{ textAlign: "left" }}>
              <strong>Status:</strong> Ready for final cryptographic submission and evaluation.
            </div>

            <button className="btn" onClick={handleFinalSubmit} disabled={loading}>
              {loading ? "Submitting Final Assessment..." : "Submit Final Assessment"}
            </button>
          </div>
        )}

        {/* 5. RESULT VIEW */}
        {view === "result" && (
          <div className="card">
            <h1>Assessment Result</h1>
            <p>Your assessment has been successfully scored by the AICQ foundation engine.</p>

            {resultData ? (
              <div style={{ background: "#f8fafc", padding: "1.5rem", borderRadius: "8px", border: "1px solid var(--border)", marginBottom: "1.5rem" }}>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "1rem" }}>
                  <span>Attempt Status:</span>
                  <strong className="badge badge-success">{resultData.status || "Submitted"}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between", marginBottom: "1rem" }}>
                  <span>Score:</span>
                  <strong>{resultData.score != null ? `${resultData.score}%` : "Evaluated"}</strong>
                </div>
                <div style={{ display: "flex", justifyContent: "space-between" }}>
                  <span>Completed At:</span>
                  <strong>{new Date().toLocaleString()}</strong>
                </div>
              </div>
            ) : (
              <div className="success-banner">
                Attempt successfully submitted and queued for reporting.
              </div>
            )}

            <button
              className="btn btn-secondary"
              onClick={() => {
                localStorage.removeItem("aicq_attempt");
                localStorage.removeItem("aicq_session");
                setAttemptData(null);
                setSessionToken("");
                setView("entry");
              }}
            >
              Start New Attempt
            </button>
          </div>
        )}
      </main>
    </div>
  );
}
