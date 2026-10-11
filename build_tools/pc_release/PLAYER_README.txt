STASIUM XII - PC launcher (Windows 10/11, 64-bit)
Launcher build {version}

Install once:
1. Unzip this folder somewhere you can write to: Desktop, Documents or
   a games folder. Not "Program Files".
2. Double-click StasiumXII.exe.
   Windows SmartScreen may say "Windows protected your PC" because the game
   is not code-signed yet. Click "More info", then "Run anyway".
   Some antivirus tools also scan or hold new unsigned games the first time.
3. The launcher downloads the game (about 600 MB the first time), checks
   every file, then shows PLAY.

After that, just open StasiumXII.exe. It checks for an update every time,
downloads only what changed, and then lets you play. A cut download picks
up where it stopped.

Buttons:
- PLAY: start the game.
- Update: check again, or retry a failed download.
- Repair: re-check every file and download again any that are damaged.
- Visual settings: the same Visuals sheet as Esc in game (Performance mode
  for slower PCs).

Files the launcher keeps next to the exe:
  StasiumXII.exe      the engine (rarely changes)
  StasiumXII.pck      the launcher itself
  content\            the game data: one base pack plus small patch packs
  install.json        what is installed

To uninstall, delete the folder. Saved settings live in
%APPDATA%\Godot\app_userdata\STASIUM XII (PC).
