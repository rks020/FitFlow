-- Allow members to view their own data in the members table
CREATE POLICY IF NOT EXISTS "Members can view own member data" 
ON members FOR SELECT 
USING (auth.uid() = id);

-- Allow members to update their own notification settings
CREATE POLICY IF NOT EXISTS "Members can update own member data" 
ON members FOR UPDATE 
USING (auth.uid() = id)
WITH CHECK (auth.uid() = id);

-- WATER LOGS POLICIES
-- Ensure RLS is enabled
ALTER TABLE IF EXISTS water_logs ENABLE ROW LEVEL SECURITY;

-- Allow members to manage their own water logs
CREATE POLICY IF NOT EXISTS "Members can view own water logs"
ON water_logs FOR SELECT
USING (auth.uid() = member_id);

CREATE POLICY IF NOT EXISTS "Members can insert own water logs"
ON water_logs FOR INSERT
WITH CHECK (auth.uid() = member_id);

CREATE POLICY IF NOT EXISTS "Members can delete own water logs"
ON water_logs FOR DELETE
USING (auth.uid() = member_id);
