import React from 'react';
import { render, screen, fireEvent } from '@testing-library/react';
import App from '../App.jsx';

describe('AICQ Participant Frontend', () => {
  it('renders start assessment form by default', () => {
    render(<App />);
    expect(screen.getByText(/Start Assessment/i)).toBeDefined();
    expect(screen.getByText(/Begin Assessment/i)).toBeDefined();
  });
});
