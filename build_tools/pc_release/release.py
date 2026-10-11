#!/usr/bin/env python3
"""One-command PC release for the STASIUM XII launcher.

  python3 build_tools/pc_release/release.py --ref origin/pc/world-zones --news "..."

1. Checks out --ref into a reusable build worktree (sparse: no docs/), copies
   this folder's export_presets.cfg over the root one and applies
   project_overrides.json to project.godot. Nothing is committed: the root
   files stay the shared mobile ones.
2. Imports and exports the Windows build: StasiumXII.exe (engine), the
   content pack, and StasiumXII.pck (the launcher pack, main pack of the exe).
3. Diffs the content pack against the previous release's file list
   (<channel>/state/<version>.json.gz: path -> md5, size) and writes a patch
   pack holding only changed and added files, plus removal entries for deleted
   ones. A full base is published instead on the first release, on --rebase,
   when the Godot version changes, or when the patch chain would pass
   --max-patches or --max-chain-mb.
4. Splits every new file into <= 90 MiB chunks, writes <channel>/latest.json,
   and pushes to the pc-builds branch through a shallow, sparse clone, chunk
   batches first and the manifest last.

--dry-run does all of it except the push and leaves the tree in --work-dir.
--publish-dir DIR writes the channel into a local folder instead of git
(used for the local HTTP server proof).
"""

from __future__ import annotations

import argparse
import datetime as dt
import gzip
import json
import os
import re
import shutil
import subprocess
import sys
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
import pck  # noqa: E402

CHUNK = 90 * 1024 * 1024
EXE = "StasiumXII.exe"
LAUNCHER_PACK = "StasiumXII.pck"
ZIP_NAME = "StasiumXII_Launcher.zip"
REMOTE_BRANCH = "pc-builds"
FOOTER = (
    "\n\nCo-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>\n"
    "Claude-Session: https://claude.ai/code/session_01KZYthtKS5y9wB5NtyQUxTJ\n"
)


def log(*a):
    print("[release]", *a, flush=True)


def run(cmd, cwd=None, check=True, capture=False, timeout=None, env=None):
    log("$", " ".join(cmd) if isinstance(cmd, list) else cmd)
    r = subprocess.run(cmd, cwd=cwd, check=False, text=True, timeout=timeout, env=env,
                       stdout=subprocess.PIPE if capture else None,
                       stderr=subprocess.STDOUT if capture else None)
    if check and r.returncode != 0:
        if capture:
            print(r.stdout[-4000:])
        raise SystemExit(f"command failed ({r.returncode}): {cmd}")
    return r


def git(*args, cwd, capture=True, check=True):
    r = run(["git", *args], cwd=cwd, capture=capture, check=check)
    return (r.stdout or "").strip()


def rm_tree(path):
    if path and os.path.isdir(path):
        shutil.rmtree(path)


# --- build checkout -----------------------------------------------------------

def prepare_checkout(repo, build_dir, ref, seed_from):
    sha = git("rev-parse", "--verify", ref + "^{commit}", cwd=repo)
    if not os.path.isdir(build_dir):
        git("worktree", "add", "--no-checkout", "--detach", build_dir, sha, cwd=repo, capture=False)
        git("sparse-checkout", "init", "--no-cone", cwd=build_dir)
        git("sparse-checkout", "set", "--no-cone", "/*", "!/docs/", cwd=build_dir)
        git("reset", "--hard", "-q", sha, cwd=build_dir)
    else:
        git("checkout", "-q", "--detach", "-f", sha, cwd=build_dir)
        git("reset", "--hard", "-q", sha, cwd=build_dir)
    # Untracked leftovers go. The import cache (.godot, ignored) and the
    # untracked *.import / *.uid files stay: most art has no committed .import,
    # and regenerating one gives it a new uid, which would show up in every patch.
    git("clean", "-ffdq", "-e", "*.import", "-e", "*.uid", cwd=build_dir)
    if seed_from:
        seed_checkout(seed_from, build_dir)
    return sha


def seed_checkout(src, build_dir):
    """Copy another worktree's import cache and its untracked .import/.uid
    files (only where the build checkout has none), so the first build does
    not re-import everything and keeps the uids players already have."""
    if not os.path.isdir(os.path.join(build_dir, ".godot")) and os.path.isdir(os.path.join(src, ".godot")):
        log("seeding the import cache from", src)
        shutil.copytree(os.path.join(src, ".godot"), os.path.join(build_dir, ".godot"), symlinks=True)
    out = git("ls-files", "--others", "--exclude-standard", "-z", cwd=src)
    copied = 0
    for rel in out.split("\0"):
        if not rel.endswith((".import", ".uid")) or rel.startswith(("docs/", "builds/")):
            continue
        dst = os.path.join(build_dir, rel)
        if os.path.exists(dst) or not os.path.isdir(os.path.dirname(dst)):
            continue
        shutil.copy2(os.path.join(src, rel), dst)
        copied += 1
    log(f"seeded {copied} untracked .import/.uid files from {src}")


def apply_overrides(build_dir):
    with open(os.path.join(HERE, "export_presets.cfg")) as f:
        presets = f.read()
    # The "resources" filter does not follow preloads inside scripts, so the
    # Launcher preset lists every file under res://launcher/ explicitly.
    files = []
    for dirpath, _dirs, names in os.walk(os.path.join(build_dir, "launcher")):
        for n in sorted(names):
            if not n.endswith((".import", ".uid")):
                rel = os.path.relpath(os.path.join(dirpath, n), build_dir)
                files.append('"res://%s"' % rel.replace(os.sep, "/"))
    presets = re.sub(r'(?m)^export_files=PackedStringArray\("res://launcher/.*$',
                     lambda _m: "export_files=PackedStringArray(%s)" % ", ".join(sorted(files)), presets)
    with open(os.path.join(build_dir, "export_presets.cfg"), "w") as f:
        f.write(presets)
    with open(os.path.join(HERE, "project_overrides.json")) as f:
        ov = json.load(f)
    path = os.path.join(build_dir, "project.godot")
    with open(path) as f:
        text = f.read()
    for section, keys in ov.get("set", {}).items():
        for key, value in keys.items():
            text = set_project_key(text, section, key, value)
    for name, value in reversed(list(ov.get("autoload_first", {}).items())):
        text = re.sub(rf"(?m)^{re.escape(name)}=.*\n", "", text)
        if "\n[autoload]\n" not in text:
            text += "\n[autoload]\n\n"
        text = text.replace("\n[autoload]\n\n", f"\n[autoload]\n\n{name}={value}\n", 1)
    with open(path, "w") as f:
        f.write(text)


def set_project_key(text, section, key, value):
    head = f"[{section}]"
    start = text.find("\n" + head + "\n")
    if start < 0:
        return text + f"\n{head}\n\n{key}={value}\n"
    body_start = start + len(head) + 2
    nxt = text.find("\n[", body_start)
    body_end = len(text) if nxt < 0 else nxt
    body = text[body_start:body_end]
    line = re.compile(rf"(?m)^{re.escape(key)}=.*$")
    if line.search(body):
        body = line.sub(lambda _m: f"{key}={value}", body, count=1)
    else:
        body = body.rstrip("\n") + f"\n{key}={value}\n"
    return text[:body_start] + body + text[body_end:]


def export(godot, build_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    run([godot, "--headless", "--path", build_dir, "--import"], timeout=3600, capture=True, check=False)
    exe = os.path.join(out_dir, EXE)
    run([godot, "--headless", "--path", build_dir, "--export-release", "Windows", exe], timeout=3600, capture=True)
    content = os.path.join(out_dir, "content_full.pck")
    os.replace(os.path.join(out_dir, LAUNCHER_PACK), content)
    raw = os.path.join(out_dir, "launcher_raw.pck")
    run([godot, "--headless", "--path", build_dir, "--export-pack", "Launcher", raw], timeout=1800, capture=True)
    launcher = os.path.join(out_dir, LAUNCHER_PACK)
    keep_launcher_only(raw, launcher)
    os.remove(raw)
    for f in os.listdir(out_dir):  # console wrapper, if a debug option ever adds one
        if f.endswith(".console.exe"):
            os.remove(os.path.join(out_dir, f))
    check_content(content)
    return exe, content, launcher


def keep_launcher_only(src, dst):
    """The launcher export also drags in the game's autoload scripts. Keep
    res://launcher/ and the files it points at, plus the engine caches."""
    p = pck.read_pack(src)
    by = p.by_path()
    keep = {"project.binary", ".godot/uid_cache.bin", ".godot/global_script_class_cache.cfg"}
    for e in p.entries:
        if e.path.startswith("launcher/"):
            keep.add(e.path)
            if e.path.endswith((".remap", ".import")):
                text = b"".join(pck.iter_data(src, e)).decode("utf-8", "replace")
                for ref in re.findall(r'res://(\.godot/[^"\s]+)', text):
                    keep.add(ref)
    items = [(path, (src, by[path])) for path in sorted(keep) if path in by]
    pck.write_pack(dst, p.version, p.engine, items)
    log(f"launcher pack: {len(items)} of {len(p.entries)} files kept, {os.path.getsize(dst)} bytes")


def check_content(content):
    bad = [e.path for e in pck.read_pack(content).entries if e.path.startswith("launcher/")]
    if bad:
        raise SystemExit(f"content pack must not carry res://launcher/ ({bad[:3]})")


# --- publish tree ----------------------------------------------------------------

class Publisher:
    """The pc-builds tree: a shallow sparse clone, or a plain local folder."""

    def __init__(self, args, work):
        self.local = args.publish_dir
        self.dry = args.dry_run
        self.channel = args.channel
        if self.local:
            self.root = os.path.abspath(self.local)
            os.makedirs(self.root, exist_ok=True)
            self.git = False
            return
        self.git = True
        self.root = os.path.join(work, "pc-builds")
        rm_tree(self.root)
        url = git("remote", "get-url", "origin", cwd=args.repo)
        git("clone", "--depth", "1", "--filter=blob:none", "--sparse", "--branch", REMOTE_BRANCH,
            url, self.root, cwd=work, capture=False)
        pats = ["/README.txt"]
        for ch in {args.channel, args.from_channel or args.channel}:
            pats += [f"/{ch}/latest.json", f"/{ch}/state/", f"/{ch}/manifests/"]
        git("sparse-checkout", "set", "--no-cone", *pats, cwd=self.root)

    def path(self, *parts):
        return os.path.join(self.root, *parts)

    def read_json(self, rel):
        p = self.path(rel)
        if not os.path.exists(p):
            return None
        with open(p) as f:
            return json.load(f)

    def tracked_dirs(self, rel):
        """Folders directly under rel, including ones outside the sparse checkout."""
        if not self.git:
            p = self.path(rel)
            return sorted(os.listdir(p)) if os.path.isdir(p) else []
        out = git("ls-tree", "--name-only", "HEAD", rel.rstrip("/") + "/", cwd=self.root)
        return sorted(os.path.basename(x) for x in out.splitlines() if x)

    def remove_dir(self, rel):
        if self.git:
            git("rm", "-r", "-q", "--sparse", "--cached", "--ignore-unmatch", rel, cwd=self.root)
        rm_tree(self.path(rel))

    def commit_push(self, files, message):
        if not self.git:
            return
        git("add", "--sparse", "-f", *files, cwd=self.root)
        if not git("status", "--porcelain", cwd=self.root):
            return
        git("commit", "-q", "-m", message + FOOTER, cwd=self.root)
        if self.dry:
            log("dry run: not pushing", message)
            return
        for attempt in range(4):
            r = run(["git", "push", "origin", f"HEAD:{REMOTE_BRANCH}"], cwd=self.root, check=False)
            if r.returncode == 0:
                return
            log("push failed, retrying", attempt + 1)
        raise SystemExit("git push failed")


def chunk_file(src, dest_dir, name, on_chunk=None):
    """Splits src into dest_dir/name.partNN. Returns the chunk rows.
    on_chunk(row) runs as each chunk is closed (to push and drop it early)."""
    os.makedirs(dest_dir, exist_ok=True)
    rows = []
    with open(src, "rb") as f:
        i = 0
        while True:
            part = os.path.join(dest_dir, f"{name}.part{i:02d}")
            h = __import__("hashlib").sha256()
            size = 0
            with open(part, "wb") as out:
                while size < CHUNK:
                    b = f.read(min(1 << 20, CHUNK - size))
                    if not b:
                        break
                    out.write(b)
                    h.update(b)
                    size += len(b)
            if size == 0:
                os.remove(part)
                break
            rows.append({"file": part, "size": size, "sha256": h.hexdigest()})
            if on_chunk:
                on_chunk(rows[-1])
            i += 1
    return rows


def next_version(prev, today):
    stamp = today.strftime("%Y.%m.%d")
    if prev and prev.startswith(stamp + "."):
        return f"{stamp}.{int(prev.split('.')[-1]) + 1}"
    return f"{stamp}.1"


def engine_of(godot):
    out = subprocess.run([godot, "--version"], capture_output=True, text=True).stdout.strip()
    return ".".join(out.split(".")[:3])


# --- main ----------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--ref", default="origin/pc/world-zones", help="git ref to build (must contain launcher/)")
    ap.add_argument("--version", help="release version, default YYYY.MM.DD.N")
    ap.add_argument("--news", help="news text shown in the launcher")
    ap.add_argument("--news-file", help="read the news text from a file")
    ap.add_argument("--channel", default="launcher", help="folder on pc-builds (launcher = live, launcher-test = proofs)")
    ap.add_argument("--from-channel", help="read the previous release from this channel instead (first test release)")
    ap.add_argument("--rebase", action="store_true", help="publish a full base even if a patch would do")
    ap.add_argument("--max-patches", type=int, default=6, help="re-base when the chain would hold more patches")
    ap.add_argument("--max-chain-mb", type=float, default=250.0, help="re-base when the patches would pass this many MB")
    ap.add_argument("--zip", action="store_true", help="also publish the one-time player download " + ZIP_NAME)
    ap.add_argument("--dry-run", action="store_true", help="build and stage everything, but do not push")
    ap.add_argument("--publish-dir", help="write into this local folder instead of the pc-builds branch")
    ap.add_argument("--build-dir", default="/home/user/wt/pc_release_build", help="reusable build worktree")
    ap.add_argument("--work-dir", default=os.path.join(os.environ.get("TMPDIR", "/tmp"), "stasium_pc_release"))
    ap.add_argument("--seed-from", help="worktree whose import cache and untracked .import/.uid files seed the build checkout")
    ap.add_argument("--godot", default="godot")
    ap.add_argument("--repo", default=None, help="git repo (defaults to the one holding this script)")
    ap.add_argument("--keep-build", action="store_true", help="keep the exported files in --work-dir/out")
    ap.add_argument("--reuse-export", action="store_true", help="reuse --work-dir/out if it was exported from the same commit")
    ap.add_argument("--export-only", action="store_true", help="stop after exporting into --work-dir/out")
    args = ap.parse_args()
    args.repo = args.repo or git("rev-parse", "--show-toplevel", cwd=HERE)

    work = os.path.abspath(args.work_dir)
    os.makedirs(work, exist_ok=True)
    out_dir = os.path.join(work, "out")
    pub = Publisher(args, work)
    ch = args.channel
    prev_ch = args.from_channel or ch
    prev = pub.read_json(f"{ch}/latest.json") or (pub.read_json(f"{prev_ch}/latest.json") if prev_ch != ch else None)
    prev_from = ch if pub.read_json(f"{ch}/latest.json") else prev_ch
    prev_state = None
    if prev:
        sp = pub.path(prev_from, prev["state"])
        with gzip.open(sp, "rt") as f:
            prev_state = json.load(f)["files"]
        log(f"previous release {prev['version']} ({len(prev['packs'])} packs) from {prev_from}/")

    today = dt.datetime.now(dt.timezone.utc)
    version = args.version or next_version(prev["version"] if prev else None, today)
    if prev and compare(version, prev["version"]) <= 0:
        raise SystemExit(f"version {version} is not newer than {prev['version']}")
    sha = prepare_checkout(args.repo, args.build_dir, args.ref, args.seed_from)
    if not os.path.isfile(os.path.join(args.build_dir, "launcher", "launcher_boot.gd")):
        raise SystemExit(f"{args.ref} has no launcher/ folder")
    apply_overrides(args.build_dir)
    engine = engine_of(args.godot)
    info_path = os.path.join(out_dir, "build_info.json")
    reuse = False
    if args.reuse_export and os.path.exists(info_path):
        with open(info_path) as f:
            reuse = json.load(f).get("sha") == sha
    if reuse:
        log("reusing the export in", out_dir)
        exe, content, launcher = (os.path.join(out_dir, n) for n in (EXE, "content_full.pck", LAUNCHER_PACK))
    else:
        rm_tree(out_dir)
        exe, content, launcher = export(args.godot, args.build_dir, out_dir)
        with open(info_path, "w") as f:
            json.dump({"sha": sha, "ref": args.ref}, f)
    git("checkout", "-q", "--", "project.godot", "export_presets.cfg", cwd=args.build_dir)
    if args.export_only:
        log("exported to", out_dir)
        return

    content_pack = pck.read_pack(content)
    new_state = pck.file_state(content_pack)
    reason = ""
    if not prev:
        reason = "first release"
    elif args.rebase:
        reason = "--rebase"
    elif prev.get("engine") != engine:
        reason = f"engine changed {prev.get('engine')} -> {engine}"
    changed, removed = pck.diff_states(prev_state or {}, new_state)
    patch_bytes = sum(new_state[p][1] for p in changed)
    if not reason and prev:
        patches = [p for p in prev["packs"] if p["kind"] == "patch"]
        chain = sum(p["size"] for p in patches) + patch_bytes
        if (changed or removed) and len(patches) + 1 > args.max_patches:
            reason = f"chain would hold {len(patches) + 1} patches (max {args.max_patches})"
        elif chain > args.max_chain_mb * 1024 * 1024:
            reason = f"patches would total {chain / 1048576:.0f} MB (max {args.max_chain_mb:.0f})"
    log(f"diff vs previous: {len(changed)} changed/added ({patch_bytes} bytes), {len(removed)} removed")

    files_rel = f"{ch}/files/{version}"
    files_dir = pub.path(files_rel)
    os.makedirs(files_dir, exist_ok=True)
    pending = []  # chunks written but not pushed yet

    def flush(force=False):
        # Push chunks in batches as they are cut (the container can restart and
        # the disk is small); the manifest goes last, so it never names a chunk
        # that is not on the branch yet.
        if pending and (force or sum(os.path.getsize(f) for f in pending) >= 2 * CHUNK):
            pub.commit_push(list(pending), f"PC launcher {ch} {version}: data {os.path.basename(pending[0])}")
            drop_local(pub, pending)
            pending.clear()

    def on_chunk(row):
        pending.append(row["file"])
        flush()

    def published(src, name, prev_entry):
        digest = pck.sha256_file(src)
        size = os.path.getsize(src)
        if prev_entry and prev_entry["sha256"] == digest:
            return dict(prev_entry), False
        rows = chunk_file(src, files_dir, name, on_chunk)
        chunks = [{"url": os.path.relpath(r["file"], pub.path(ch)), "size": r["size"], "sha256": r["sha256"]}
                  for r in rows]
        return {"name": name, "sha256": digest, "size": size, "chunks": chunks}, True

    if reason:
        log("publishing a full base:", reason)
        name = f"base-{version}.pck"
        os.replace(content, os.path.join(out_dir, name))
        entry, _ = published(os.path.join(out_dir, name), name, None)
        entry.update({"kind": "base", "version": version, "files": len(new_state)})
        packs = [entry]
        os.remove(os.path.join(out_dir, name))
    else:
        packs = [dict(p) for p in prev["packs"]]
        if prev_from != ch:  # first release of a new channel: point at the old channel's chunks
            for p in packs:
                p["chunks"] = [dict(c, url="../" + prev_from + "/" + c["url"]) for c in p["chunks"]]
        if changed or removed:
            name = f"patch-{version}.pck"
            ppath = os.path.join(out_dir, name)
            by = content_pack.by_path()
            items = [(p, (content, by[p])) for p in changed] + [(p, None) for p in removed]
            pck.write_pack(ppath, content_pack.version, content_pack.engine, items)
            os.remove(content)
            entry, _ = published(ppath, name, None)
            entry.update({"kind": "patch", "version": version, "files": len(changed), "removed": len(removed)})
            packs.append(entry)
            os.remove(ppath)
            log(f"patch {name}: {entry['size']} bytes")
        else:
            os.remove(content)
            log("content unchanged: no new pack")

    def carried(role):
        """The previous exe/launcher entry, with urls valid from this channel."""
        if not prev:
            return None
        e = dict(prev[role])
        if prev_from != ch:
            e["chunks"] = [dict(c, url="../" + prev_from + "/" + c["url"]) for c in e["chunks"]]
        return e

    prev_exe, prev_launcher = carried("exe"), carried("launcher")
    exe_entry, _ = published(exe, EXE, prev_exe)
    launcher_entry, _ = published(launcher, LAUNCHER_PACK, prev_launcher)

    news = args.news
    if args.news_file:
        with open(args.news_file) as f:
            news = f.read().strip()
    if not news:
        news = f"Build {version}."
    state_rel = f"state/{version}.json.gz"
    os.makedirs(pub.path(ch, "state"), exist_ok=True)
    with gzip.open(pub.path(ch, state_rel), "wt") as f:
        json.dump({"version": version, "files": new_state}, f, separators=(",", ":"))
    manifest = {
        "format": 1,
        "version": version,
        "date": today.strftime("%Y-%m-%d"),
        "source_ref": f"{args.ref} {sha[:9]}",
        "engine": engine,
        "news": news,
        "exe": exe_entry,
        "launcher": launcher_entry,
        "packs": packs,
        "state": state_rel,
        "download_total": sum(p["size"] for p in packs),
    }
    os.makedirs(pub.path(ch, "manifests"), exist_ok=True)
    for rel in (f"{ch}/manifests/{version}.json", f"{ch}/latest.json"):
        with open(pub.path(rel), "w") as f:
            json.dump(manifest, f, indent=2)
            f.write("\n")

    zip_rel = None
    if args.zip:
        zip_rel = ZIP_NAME if ch == "launcher" else f"{ch}/{ZIP_NAME}"
        make_zip(pub.path(zip_rel), exe, launcher, version)
        log(f"{zip_rel}: {os.path.getsize(pub.path(zip_rel))} bytes")
    if not args.keep_build:
        rm_tree(out_dir)

    # Chunk folders the new manifest no longer points at (replaced by a re-base).
    referenced = set()
    for e in [manifest["exe"], manifest["launcher"], *manifest["packs"]]:
        for c in e["chunks"]:
            m = re.match(r"files/([^/]+)/", c["url"])
            if m:
                referenced.add(m.group(1))
    for d in pub.tracked_dirs(f"{ch}/files"):
        if d not in referenced:
            log("dropping unreferenced", f"{ch}/files/{d}")
            pub.remove_dir(f"{ch}/files/{d}")
    if os.path.isdir(files_dir) and not os.listdir(files_dir) and not pub.git:
        os.rmdir(files_dir)

    flush(force=True)
    final = [pub.path(f"{ch}/latest.json"), pub.path(f"{ch}/manifests/{version}.json"), pub.path(ch, state_rel)]
    if zip_rel:
        final.append(pub.path(zip_rel))
    kinds = "+".join(p["kind"] for p in packs)
    pub.commit_push(final, f"PC launcher {ch} {version} ({kinds})\n\n{news}")
    if zip_rel and pub.git:
        drop_local(pub, [pub.path(zip_rel)])
    summary = {
        "version": version, "channel": ch, "packs": [(p["name"], p["size"]) for p in packs],
        "new_pack": packs[-1]["name"] if packs and packs[-1]["version"] == version else None,
        "exe_changed": prev_exe is None or prev_exe["sha256"] != exe_entry["sha256"],
        "launcher_changed": prev_launcher is None or prev_launcher["sha256"] != launcher_entry["sha256"],
        "changed_files": len(changed), "removed_files": len(removed), "rebase": reason or None,
        "publish_root": pub.root,
    }
    print(json.dumps(summary, indent=2))
    if pub.git and not pub.dry:
        rm_tree(pub.root)  # its .git holds every pushed chunk again


def drop_local(pub, files):
    """Pushed chunks are not needed on this disk any more."""
    if not pub.git or pub.dry:
        return
    for f in files:
        if os.path.exists(f):
            os.remove(f)


def compare(a, b):
    pa = [int(x) for x in a.split("-")[0].split(".")]
    pb = [int(x) for x in b.split("-")[0].split(".")]
    n = max(len(pa), len(pb))
    pa += [0] * (n - len(pa))
    pb += [0] * (n - len(pb))
    return (pa > pb) - (pa < pb)


def make_zip(dst, exe, launcher, version):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    with open(os.path.join(HERE, "PLAYER_README.txt")) as f:
        readme = f.read().replace("{version}", version)
    with zipfile.ZipFile(dst, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        z.write(exe, f"StasiumXII/{EXE}")
        z.write(launcher, f"StasiumXII/{LAUNCHER_PACK}")
        z.writestr("StasiumXII/README.txt", readme.replace("\n", "\r\n"))


if __name__ == "__main__":
    main()
