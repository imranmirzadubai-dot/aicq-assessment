import React, { useState, useEffect } from 'react';

export default function AssessmentFlow({ session, attemptData, onSubmitted }) {
  const { attempt, session: sessToken } = session;
  const attemptId = attempt.attempt_id;
  const headers = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${sessToken.session_token}`
  };

  const [currentPosition, setCurrentPosition] = useState(1);
  const [itemData, setItemData] = useState(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);
  const [startTime, setStartTime] = useState(Date.now());

  // Responses stored by item_version_id
  const [responses, setResponses] = useState({}); // { [itemVersionId]: { selected_option_id, skipped, confidence } }
  const [practicalSubmissions, setPracticalSubmissions] = useState({}); // { [taskVersionId]: { ordered_steps, submission_data } }

  const totalQuestions = 32; // Standard AICQ-P1 form length

  useEffect(() => {
    startAttemptIfNeeded();
  }, []);

  useEffect(() => {
    fetchItem(currentPosition);
  }, [currentPosition]);

  const startAttemptIfNeeded = async () => {
    try {
      await fetch(`/v1/attempts/${attemptId}/start`, {
        method: 'POST',
        headers
      });
    } catch {
      // Ignored if already started
    }
  };

  const fetchItem = async (pos) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch(`/v1/attempts/${attemptId}/items/${pos}`, {
        headers
      });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || 'Failed to load item.');
      }
      setItemData(data.item);
      setStartTime(Date.now());
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  const handleSelectOption = async (optionId) => {
    if (!itemData) return;
    const itemVersionId = itemData.item_version_id;
    const responseTimeMs = Date.now() - startTime;

    const currentResp = responses[itemVersionId] || {};
    const updatedResp = { ...currentResp, selected_option_id: optionId, skipped: false };
    setResponses(prev => ({ ...prev, [itemVersionId]: updatedResp }));

    try {
      await fetch(`/v1/attempts/${attemptId}/responses`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          item_version_id: itemVersionId,
          selected_option_id: optionId,
          skipped: false,
          response_time_ms: responseTimeMs,
          presentation_sequence: itemData.presentation_sequence,
          option_order: itemData.options?.map(o => o.option_id) || []
        })
      });
    } catch (err) {
      console.error('Failed to save response:', err);
    }
  };

  const handleConfidence = async (confidenceVal) => {
    if (!itemData) return;
    const itemVersionId = itemData.item_version_id;

    const currentResp = responses[itemVersionId] || {};
    const updatedResp = { ...currentResp, confidence: confidenceVal };
    setResponses(prev => ({ ...prev, [itemVersionId]: updatedResp }));

    try {
      await fetch(`/v1/attempts/${attemptId}/confidence`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          confidence: confidenceVal,
          item_version_id: itemVersionId
        })
      });
    } catch (err) {
      console.error('Failed to save confidence:', err);
    }
  };

  const handlePracticalSubmit = async (taskVersionId, orderedSteps, subData) => {
    try {
      const res = await fetch(`/v1/attempts/${attemptId}/practical`, {
        method: 'POST',
        headers,
        body: JSON.stringify({
          task_version_id: taskVersionId,
          ordered_steps: orderedSteps,
          submission_data: subData
        })
      });
      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || 'Failed to submit practical task.');
      }
      setPracticalSubmissions(prev => ({
        ...prev,
        [taskVersionId]: { ordered_steps: orderedSteps, submission_data: subData }
      }));
      alert('Practical task saved successfully!');
    } catch (err) {
      alert(`Error: ${err.message}`);
    }
  };

  const handleSubmitAttempt = async () => {
    if (!window.confirm('Are you ready to submit your final assessment? This cannot be undone.')) {
      return;
    }

    setLoading(true);
    setError(null);

    try {
      const idempotencyKey = 'sub_' + Math.random().toString(36.25).substring(2, 15) + Math.random().toString(36).substring(2, 15);

      const res = await fetch(`/v1/attempts/${attemptId}/submit`, {
        method: 'POST',
        headers: {
          ...headers,
          'Idempotency-Key': idempotencyKey
        },
        body: JSON.stringify({ submitted_at: new Date().toISOString() })
      });

      const data = await res.json();
      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || 'Failed to submit assessment.');
      }

      // Fetch result
      const resResult = await fetch(`/v1/attempts/${attemptId}/result`, {
        headers
      });
      const resultData = await resResult.json();
      if (!resResult.ok || !resultData.ok) {
        throw new Error(resultData.error?.message || 'Failed to fetch result.');
      }

      onSubmitted(resultData.result);
    } catch (err) {
      setError(err.message);
      setLoading(false);
    }
  };

  if (loading && !itemData) {
    return <div className="card"><p>Loading assessment item...</p></div>;
  }

  const currentResp = itemData ? responses[itemData.item_version_id] || {} : {};

  return (
    <div>
      <div className="card" style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center' }}>
        <div>
          <h3>Assessment: {attempt.assessment_code}</h3>
          <p style={{ margin: 0 }}>Participant: {attempt.participant_name || 'Anonymous'}</p>
        </div>
        <div style={{ textAlign: 'right' }}>
          <strong>Progress: Question {currentPosition} of {totalQuestions}</strong>
        </div>
      </div>

      {error && <div className="alert alert-error">{error}</div>}

      {itemData && (
        <div className="card">
          <div style={{ display: 'flex', justifyContent: 'space-between', marginBottom: '1rem' }}>
            <span style={{ fontWeight: 600, color: 'var(--primary)' }}>
              Competency: {itemData.competency_name || itemData.competency_code || 'General'}
            </span>
            <span>Type: {itemData.item_type || 'Multiple Choice'}</span>
          </div>

          <h3 style={{ marginBottom: '1.5rem' }}>{itemData.prompt || itemData.stem || itemData.question_text || 'Question Prompt'}</h3>

          {itemData.item_type === 'practical' ? (
            <PracticalTaskRenderer
              item={itemData}
              onSubmitPractical={handlePracticalSubmit}
              saved={practicalSubmissions[itemData.item_version_id]}
            />
          ) : (
            <>
              <div className="options-list">
                {itemData.options?.map((opt, idx) => {
                  const isSelected = currentResp.selected_option_id === opt.option_id;
                  return (
                    <div
                      key={opt.option_id || idx}
                      className={`option-item ${isSelected ? 'selected' : ''}`}
                      onClick={() => handleSelectOption(opt.option_id)}
                    >
                      <input
                        type="radio"
                        name={`item_${itemData.item_version_id}`}
                        checked={isSelected}
                        onChange={() => handleSelectOption(opt.option_id)}
                      />
                      <span>{opt.option_text || opt.text || opt.label}</span>
                    </div>
                  );
                })}
              </div>

              <div style={{ marginTop: '2rem', borderTop: '1px solid var(--border)', paddingTop: '1.5rem' }}>
                <label>Confidence Level (1 = Low, 5 = Very High):</label>
                <div style={{ display: 'flex', gap: '1rem', marginTop: '0.5rem' }}>
                  {[1, 2, 3, 4, 5].map(val => (
                    <button
                      key={val}
                      type="button"
                      className={currentResp.confidence === val ? '' : 'btn-secondary'}
                      style={{ flex: 1 }}
                      onClick={() => handleConfidence(val)}
                    >
                      {val}
                    </button>
                  ))}
                </div>
              </div>
            </>
          )}

          <div className="nav-buttons">
            <button
              className="btn-secondary"
              onClick={() => setCurrentPosition(p => Math.max(1, p - 1))}
              disabled={currentPosition === 1}
            >
              Previous
            </button>

            {currentPosition < totalQuestions ? (
              <button onClick={() => setCurrentPosition(p => Math.min(totalQuestions, p + 1))}>
                Next Question
              </button>
            ) : (
              <button style={{ backgroundColor: 'var(--success)' }} onClick={handleSubmitAttempt} disabled={loading}>
                {loading ? 'Submitting...' : 'Submit Assessment'}
              </button>
            )}
          </div>
        </div>
      )}
    </div>
  );
}

function PracticalTaskRenderer({ item, onSubmitPractical, saved }) {
  const [steps, setSteps] = useState(saved?.ordered_steps || item.steps || item.default_steps || ['Step 1', 'Step 2', 'Step 3']);
  const [notes, setNotes] = useState(saved?.submission_data?.notes || '');

  const moveStep = (index, direction) => {
    const newSteps = [...steps];
    const target = index + direction;
    if (target < 0 || target >= newSteps.length) return;
    const temp = newSteps[index];
    newSteps[index] = newSteps[target];
    newSteps[target] = temp;
    setSteps(newSteps);
  };

  const handleSave = () => {
    onSubmitPractical(item.task_version_id || item.item_version_id, steps, { notes });
  };

  return (
    <div>
      <p>Order the operational steps correctly and add your notes:</p>
      <div className="steps-list">
        {steps.map((step, idx) => (
          <div key={idx} className="step-card">
            <span>{idx + 1}. {typeof step === 'string' ? step : step.title || step.description}</span>
            <div style={{ display: 'flex', gap: '0.5rem' }}>
              <button type="button" className="btn-secondary" style={{ padding: '0.25rem 0.5rem' }} onClick={() => moveStep(idx, -1)} disabled={idx === 0}>↑</button>
              <button type="button" className="btn-secondary" style={{ padding: '0.25rem 0.5rem' }} onClick={() => moveStep(idx, 1)} disabled={idx === steps.length - 1}>↓</button>
            </div>
          </div>
        ))}
      </div>

      <div className="form-group" style={{ marginTop: '1rem' }}>
        <label>Execution Notes / Rationale</label>
        <textarea
          rows="4"
          value={notes}
          onChange={(e) => setNotes(e.target.value)}
          placeholder="Describe your reasoning and execution approach..."
        />
      </div>

      <button type="button" onClick={handleSave}>
        Save Practical Submission
      </button>
    </div>
  );
}
