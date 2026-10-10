extends RefCounted

## Supabase project for player accounts (Mauro 10 Oct 2026: "every single
## player has its account and save their progress"; "email and guest").
##
## Paste the Project URL and the anon (public) key from the Supabase
## dashboard (Project Settings > API). Both are public by design: the anon
## key only does what the project's Row Level Security allows.
##
## NEVER put the service_role key here or anywhere in this repo. It skips
## every security rule and would ship inside the APK. It belongs only on
## the dedicated server (Step 3, environment variable).
##
## While these are empty the hub shows "Accounts are not connected yet"
## and the game keeps saving on the phone as before.

const SUPABASE_URL := ""
const SUPABASE_ANON_KEY := ""
