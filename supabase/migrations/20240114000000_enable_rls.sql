-- Enable RLS on tables
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE organizations ENABLE ROW LEVEL SECURITY;
ALTER TABLE members ENABLE ROW LEVEL SECURITY;

-- PROFILES POLICIES
-- Users can see their own profile
CREATE POLICY "Users can view own profile" 
ON profiles FOR SELECT 
USING (auth.uid() = id);

-- Users can update their own profile
CREATE POLICY "Users can update own profile" 
ON profiles FOR UPDATE 
USING (auth.uid() = id);

-- Users can insert their own profile (for registration)
CREATE POLICY "Users can insert own profile" 
ON profiles FOR INSERT 
WITH CHECK (auth.uid() = id);

-- ORGANIZATIONS POLICIES
-- Gym owners can view their own organization
CREATE POLICY "Owners can view own organization" 
ON organizations FOR SELECT 
USING (auth.uid() = owner_id);

-- Gym owners can insert their own organization
CREATE POLICY "Owners can create organization" 
ON organizations FOR INSERT 
WITH CHECK (auth.uid() = owner_id);

-- Gym owners can update their own organization
CREATE POLICY "Owners can update own organization" 
ON organizations FOR UPDATE 
USING (auth.uid() = owner_id);


-- MEMBERS POLICIES
-- Gym owners can view members of their organization
-- We link members -> organization -> owner_id
CREATE POLICY "Owners can view their members" 
ON members FOR SELECT 
USING (
  organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  )
);

-- Gym owners can create members in their organization
CREATE POLICY "Owners can create members" 
ON members FOR INSERT 
WITH CHECK (
  organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  )
);

-- Gym owners can update their members
CREATE POLICY "Owners can update their members" 
ON members FOR UPDATE 
USING (
  organization_id IN (
    SELECT id FROM organizations WHERE owner_id = auth.uid()
  )
);
