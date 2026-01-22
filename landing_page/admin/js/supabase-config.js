// Supabase Configuration
const SUPABASE_URL = 'https://hrywsorgjitwedsnlbyp.supabase.co';
const SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhyeXdzb3Jnaml0d2Vkc25sYnlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjY0MDAyODMsImV4cCI6MjA4MTk3NjI4M30.PVjY7BSJz1UBm7UOvr9r9qcupshnprdZ-BL7rTkcaRc';

// Initialize Supabase Client
const { createClient } = supabase;
const supabaseClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

export { supabaseClient };
