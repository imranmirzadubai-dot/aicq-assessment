import React from 'react';

export default function ResultView({ session, result }) {
  const attempt = session?.attempt || {};

  return (
    <div className="card">
      <div className="alert alert-success">
        Assessment submitted successfully! Your attempt has been recorded and evaluated.
      </div>

      <h2>Assessment Results</h2>
      <p>Participant: <strong>{attempt.participant_name || 'Anonymous'}</strong></p>
      <p>Assessment Code: <strong>{attempt.assessment_code}</strong></p>

      {result ? (
        <div style={{ marginTop: '1.5rem' }}>
          <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '1rem', marginBottom: '2rem' }}>
            <div className="card" style={{ textAlign: 'center', marginBottom: 0 }}>
              <h4>Overall Score</h4>
              <p style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--primary)', margin: 0 }}>
                {result.overall_score != null ? `${Math.round(result.overall_score)}%` : 'Completed'}
              </p>
            </div>
            {result.knowledge_score != null && (
              <div className="card" style={{ textAlign: 'center', marginBottom: 0 }}>
                <h4>Knowledge Score</h4>
                <p style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--text)', margin: 0 }}>
                  {Math.round(result.knowledge_score)}%
                </p>
              </div>
            )}
            {result.practical_score != null && (
              <div className="card" style={{ textAlign: 'center', marginBottom: 0 }}>
                <h4>Practical Score</h4>
                <p style={{ fontSize: '2rem', fontWeight: 700, color: 'var(--text)', margin: 0 }}>
                  {Math.round(result.practical_score)}%
                </p>
              </div>
            )}
          </div>

          {result.interpretation && (
            <div style={{ marginBottom: '1.5rem' }}>
              <h4>Interpretation</h4>
              <p>{result.interpretation}</p>
            </div>
          )}
        </div>
      ) : (
        <p>Your results are being compiled. Thank you for participating.</p>
      )}

      <button onClick={() => window.location.reload()} style={{ marginTop: '1rem' }}>
        Start New Session
      </button>
    </div>
  );
}
