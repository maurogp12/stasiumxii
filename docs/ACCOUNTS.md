# Player accounts (mobile)

Mauro, 10 Oct 2026: "We need to start working on setting up a account
creation for the game so every single player has its account and save their
progress" → "Yes you build it, email and guest, start now".

Backend: **Supabase** (hosted auth + Postgres; free tier). Grok's status
issue #333 recommended the same. Godot talks to it with plain `HTTPRequest`
calls, so there is no plugin.

## Plan (one step at a time, Mauro approves each)

| Step | What | Status |
|---|---|---|
| 1 | Account screen: create account (name + email + password), log in, play as guest, guest adds email + password later (same account), log out. Hub **Account** button shows the player name. | **Built (this branch)** |
| 2 | Cloud save: the 4 progress files (`hero_progress.json`, `gear_bag.json`, `stills.json`, `koliseo_wallet.json`) saved to the account and loaded on any phone. First login uploads the phone's progress. Works offline, syncs later. | Not started |
| 3 | No cheating online: the dedicated server checks the player's login, reads gear from the account, and pays coins / trophies / XP itself. The server's `service_role` key lives only on the server. | Not started |
| 4 | Later: Google sign-in, password reset email, delete account. | Not started |

## Step 1 files

- `backend/account_config.gd`: `SUPABASE_URL` and `SUPABASE_ANON_KEY`.
  **Empty until Mauro creates the project.** While empty, the hub button
  reads "Log in", the screen says "Accounts are not connected yet", the
  screen never opens by itself, and the game plays exactly as before.
- `backend/account_logic.gd`: pure helpers: input checks, the Supabase Auth
  requests, reading answers, plain-words messages, the saved login
  (`user://account.json`).
- `backend/account_client.gd`: the network node (one call at a time; tests
  inject a fake `transport`).
- `scenes/account_screen.gd`: the overlay (welcome / log in / create /
  guest / add email / signed in).
- `scenes/mobile_hub.gd`: **Account** button in the top row; the screen
  opens by itself once per app start when accounts are connected and nobody
  is logged in.
- `tests/run_account_tests.gd` (suite), `tests/shot_account.gd` (phone
  screenshots).

Rules in Step 1:

- Player name: 3–16 letters, numbers, space, `_`, `-`. Stored in the
  Supabase user's `user_metadata.display_name`.
- Password: at least 8 characters.
- A guest is a Supabase **anonymous user**. Logging out of a guest account
  loses it (the screen says so). Adding an email + password keeps the same
  account id.
- The login refreshes itself 2 minutes before it runs out. No internet keeps
  the player logged in; a dead login logs out.
- Step 1 does **not** move progress. The progress reset (`ProgressEpoch`) does
  not touch `user://account.json`.

## Supabase setup (Mauro, once)

1. Go to https://supabase.com, sign in, **New project**. Name it
   `stasiumxii`, pick a region close to the players, save the database
   password somewhere safe (it is not needed in the game).
2. **Authentication → Sign In / Providers**:
   - **Email**: on.
   - **Allow anonymous sign-ins**: on (this is "Play as guest").
   - **Confirm email**: off while testing (players log in right away). Turn
     it on before a public launch; the game already handles "check your
     email" for sign-up and for a guest adding an email.
3. **Project Settings → API**: copy the **Project URL** and the **anon
   public** key into `backend/account_config.gd` (or send them to Claude).
   They are safe inside the APK.
4. **Never** paste the **service_role** key in chat, in the repo, or in the
   game. It is only for the dedicated server in Step 3.

Supabase limits to know: anonymous sign-ups are rate limited per IP (about
30 an hour by default), and the free project pauses after a week with no
use (un-pause it from the dashboard).
