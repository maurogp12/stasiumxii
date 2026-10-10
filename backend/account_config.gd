extends RefCounted

## Supabase project for player accounts (Mauro 10 Oct 2026: "every single
## player has its account and save their progress"; "email and guest").
##
## Project URL and the publishable / anon (public) key from the Supabase
## dashboard (Project Settings > API Keys). Mauro's project "stasium",
## created 10 Oct 2026. Both are public by design: the anon
## key only does what the project's Row Level Security allows.
##
## NEVER put the service_role key here or anywhere in this repo. It skips
## every security rule and would ship inside the APK. It belongs only on
## the dedicated server (Step 3, environment variable). The same goes for
## the new-style "sb_secret_..." key.
##
## If these are emptied, the hub shows "Accounts are not connected yet"
## and the game keeps saving on the phone as before.

const SUPABASE_URL := "https://lydjxqpvcugqkipgowey.supabase.co"
## Supabase "publishable" key (the new name for the anon key). Public by design.
const SUPABASE_ANON_KEY := "sb_publishable_kH_5c0n5mOs_0AWnej9o0w_pyqFtJyb"
