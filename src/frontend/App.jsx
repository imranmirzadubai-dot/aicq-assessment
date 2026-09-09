import React, { useState } from 'react';
import EntryForm from './components/EntryForm.jsx';
import AssessmentFlow from './components/AssessmentFlow.jsx';
import ResultView from './components/ResultView.jsx';

export default function App() {
  const [session, setSession] = useState(null); // { attempt, session }
  const [attemptData, setAttemptData] = useState(null);
  const [isSubmitted, setIsSubmitted] = useState(false);
  const [result, setResult] = useState(null);

  const handleAttemptCreated = (data) => {
    setSession(data);
    setAttemptData(data.attempt);
    setIsSubmitted(false);
    setResult(null);
  };

  const handleSubmitted = (res) => {
    setIsSubmitted(true);
    setResult(res);
  };

  return (
    <div className="container">
      <header style={{ marginBottom: '2rem', textAlign: 'center' }}>
        <h1>AICQ Assessment Portal</h1>
        <p>Professional Competency & Knowledge Quantification</p>
      </header>

      {!session ? (
        <EntryForm onAttemptCreated={handleAttemptCreated} />
      ) : !isSubmitted ? (
        <AssessmentFlow session={session} attemptData={attemptData} onSubmitted={handleSubmitted} />
      ) : (
        <ResultView session={session} result={result} />
      )}
    </div>
  );
}
