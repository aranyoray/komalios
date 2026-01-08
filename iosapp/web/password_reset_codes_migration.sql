-- ============================================================================
-- Password Reset Codes Table Migration
-- Run this in your Supabase SQL Editor to enable code-based password reset
-- ============================================================================

-- Create password_reset_codes table
CREATE TABLE IF NOT EXISTS password_reset_codes (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email TEXT NOT NULL,
  code TEXT NOT NULL,
  expires_at TIMESTAMPTZ NOT NULL,
  used BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  
  -- Index for quick lookups
  CONSTRAINT password_reset_codes_email_code_key UNIQUE(email, code)
);

-- Create index for email lookups
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_email ON password_reset_codes(email);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_code ON password_reset_codes(code);
CREATE INDEX IF NOT EXISTS idx_password_reset_codes_expires ON password_reset_codes(expires_at);

-- Enable Row Level Security
ALTER TABLE password_reset_codes ENABLE ROW LEVEL SECURITY;

-- Policy: Allow anyone to insert reset codes (for password reset requests)
CREATE POLICY "Allow insert password reset codes"
  ON password_reset_codes
  FOR INSERT
  TO anon, authenticated
  WITH CHECK (true);

-- Policy: Allow anyone to read reset codes (for verification)
CREATE POLICY "Allow read password reset codes"
  ON password_reset_codes
  FOR SELECT
  TO anon, authenticated
  USING (true);

-- Policy: Allow update to mark codes as used
CREATE POLICY "Allow update password reset codes"
  ON password_reset_codes
  FOR UPDATE
  TO anon, authenticated
  USING (true)
  WITH CHECK (true);

-- Function to clean up expired codes (runs automatically)
CREATE OR REPLACE FUNCTION cleanup_expired_reset_codes()
RETURNS void AS $$
BEGIN
  DELETE FROM password_reset_codes
  WHERE expires_at < NOW() OR used = true;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create a function to generate and store reset code
CREATE OR REPLACE FUNCTION generate_password_reset_code(user_email TEXT)
RETURNS TEXT AS $$
DECLARE
  reset_code TEXT;
  code_expires TIMESTAMPTZ;
BEGIN
  -- Generate 6-digit code
  reset_code := LPAD(FLOOR(RANDOM() * 1000000)::TEXT, 6, '0');
  
  -- Set expiration to 15 minutes from now
  code_expires := NOW() + INTERVAL '15 minutes';
  
  -- Invalidate any existing codes for this email
  UPDATE password_reset_codes
  SET used = true
  WHERE email = user_email AND used = false;
  
  -- Insert new code
  INSERT INTO password_reset_codes (email, code, expires_at)
  VALUES (user_email, reset_code, code_expires)
  ON CONFLICT (email, code) DO NOTHING;
  
  -- Return the code (for email sending)
  RETURN reset_code;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to verify reset code
CREATE OR REPLACE FUNCTION verify_password_reset_code(user_email TEXT, input_code TEXT)
RETURNS BOOLEAN AS $$
DECLARE
  code_record RECORD;
BEGIN
  -- Find the code
  SELECT * INTO code_record
  FROM password_reset_codes
  WHERE email = user_email
    AND code = input_code
    AND used = false
    AND expires_at > NOW()
  ORDER BY created_at DESC
  LIMIT 1;
  
  -- If code found and valid, mark as used
  IF FOUND THEN
    UPDATE password_reset_codes
    SET used = true
    WHERE id = code_record.id;
    RETURN true;
  END IF;
  
  RETURN false;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Grant execute permissions
GRANT EXECUTE ON FUNCTION generate_password_reset_code(TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION verify_password_reset_code(TEXT, TEXT) TO anon, authenticated;
GRANT EXECUTE ON FUNCTION cleanup_expired_reset_codes() TO anon, authenticated;

