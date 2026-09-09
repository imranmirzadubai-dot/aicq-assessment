import React, { useState } from 'react';

export default function EntryForm({ onAttemptCreated }) {
  const [formData, setFormData] = useState({
    assessment_code: 'AICQ-P1',
    form_code: 'AICQ-P1-F01',
    form_version: '1.0',
    participant_name: '',
    participant_age: '',
    participant_gender: '',
    participant_occupation: '',
    participant_experience: ''
  });
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState(null);

  const handleChange = (e) => {
    const { name, value } = e.target;
    setFormData(prev => ({ ...prev, [name]: value }));
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setLoading(true);
    setError(null);

    try {
      const payload = {
        assessment_code: formData.assessment_code,
        form_code: formData.form_code,
        form_version: formData.form_version,
        participant_name: formData.participant_name || null,
        participant_age: formData.participant_age ? Number(formData.participant_age) : null,
        participant_gender: formData.participant_gender || null,
        participant_occupation: formData.participant_occupation || null,
        participant_experience: formData.participant_experience ? Number(formData.participant_experience) : null
      };

      const res = await fetch('/v1/attempts', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload)
      });

      const data = await res.json();

      if (!res.ok || !data.ok) {
        throw new Error(data.error?.message || 'Failed to create attempt.');
      }

      onAttemptCreated(data);
    } catch (err) {
      setError(err.message);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="card">
      <h2>Start Assessment</h2>
      <p>Please enter your participant details to begin your assessment session.</p>

      {error && <div className="alert alert-error">{error}</div>}

      <form onSubmit={handleSubmit}>
        <div className="form-group">
          <label>Full Name</label>
          <input
            type="text"
            name="participant_name"
            value={formData.participant_name}
            onChange={handleChange}
            placeholder="e.g. Jane Doe"
            required
          />
        </div>

        <div className="form-group">
          <label>Age</label>
          <input
            type="number"
            name="participant_age"
            value={formData.participant_age}
            onChange={handleChange}
            placeholder="e.g. 30"
            min="0"
            max="130"
          />
        </div>

        <div className="form-group">
          <label>Gender</label>
          <select name="participant_gender" value={formData.participant_gender} onChange={handleChange}>
            <option value="">Select Gender (Optional)</option>
            <option value="Female">Female</option>
            <option value="Male">Male</option>
            <option value="Other">Other/Prefer not to say</option>
          </select>
        </div>

        <div className="form-group">
          <label>Occupation / Role</label>
          <input
            type="text"
            name="participant_occupation"
            value={formData.participant_occupation}
            onChange={handleChange}
            placeholder="e.g. Software Engineer"
          />
        </div>

        <div className="form-group">
          <label>Years of Experience</label>
          <input
            type="number"
            name="participant_experience"
            value={formData.participant_experience}
            onChange={handleChange}
            placeholder="e.g. 5"
            min="0"
            max="100"
          />
        </div>

        <button type="submit" disabled={loading}>
          {loading ? 'Initializing Attempt...' : 'Begin Assessment'}
        </button>
      </form>
    </div>
  );
}
