import React from 'react';
import { render, screen } from '@testing-library/react';
import '@testing-library/jest-dom';
import EntryForm from '../components/EntryForm.jsx';

describe('EntryForm Component', () => {
  it('renders participant entry form correctly', () => {
    render(<EntryForm onAttemptCreated={() => {}} />);
    expect(screen.getByText(/Start Assessment/i)).toBeInTheDocument();
    expect(screen.getByPlaceholderText(/Jane Doe/i)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: /Begin Assessment/i })).toBeInTheDocument();
  });
});
