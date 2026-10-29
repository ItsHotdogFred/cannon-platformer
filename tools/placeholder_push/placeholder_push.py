#!/usr/bin/env python3
"""Push a copy of the repo to GitHub with every image swapped for a generated texture.

Your local branch keeps the real art. On push, this builds a shadow commit whose
tree is identical to your branch except that each image blob is replaced by a
procedurally generated texture of the same size and format, then pushes that
shadow commit instead. Your working tree and index are never touched.

Shadow commits live under refs/placeholder/<branch> and chain onto each other,
so GitHub sees a normal linear history.

Usage:
  placeholder_push.py publish [--branch master] [--remote origin] [--mode silhouette|procedural] [--tile 8] [--fresh] [--dry-run]
  placeholder_push.py preview <image-path-in-repo> <out.png> [--mode ...]
"""
import argparse
import fnmatch
import hashlib
import io
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image

IMAGE_EXTS = {".png", ".jpg", ".jpeg", ".webp", ".bmp", ".tga", ".svg"}
TRAILER = "Placeholder-Source:"
GENERATOR_VERSION = "2"  # bump to regenerate every cached texture


def git(*args, input=None, env=None, check=True):
    res = subprocess.run(["git", *args], input=input, capture_output=True, env=env)
    if check and res.returncode != 0:
        sys.exit(f"git {' '.join(args)} failed:\n{res.stderr.decode(errors='replace')}")
    return res.stdout


def git_s(*args, **kw):
    return git(*args, **kw).decode().strip()


def rev_exists(rev):
    return git("rev-parse", "--verify", "--quiet", rev, check=False).strip() != b""


# --- texture generation -------------------------------------------------------

def seed_for(path):
    return int.from_bytes(hashlib.sha256(path.encode()).digest()[:8], "little")


def hsv_to_rgb(h, s, v):
    i = int(h * 6) % 6
    f = h * 6 - int(h * 6)
    p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
    return [(v, t, p), (q, v, p), (p, v, t), (p, q, v), (t, p, v), (v, p, q)][i]


def generate_rgba(path, w, h, source_alpha=None, tile=8):
    """Deterministic texture for `path`: tinted checker + value noise + a grid on tile edges."""
    rng = np.random.default_rng(seed_for(path))
    hue = rng.random()
    base = np.array(hsv_to_rgb(hue, 0.55, 0.75))
    alt = np.array(hsv_to_rgb((hue + 0.08) % 1, 0.45, 0.6))

    ys, xs = np.mgrid[0:h, 0:w]
    cell = max(1, min(tile // 2, min(w, h) // 2))
    checker = ((xs // cell + ys // cell) % 2).astype(np.float32)[..., None]
    rgb = base * (1 - checker) + alt * checker

    # coarse value noise, upscaled, for some texture
    nw, nh = max(1, w // 4), max(1, h // 4)
    noise = rng.random((nh, nw), dtype=np.float32)
    noise = np.asarray(Image.fromarray((noise * 255).astype(np.uint8)).resize((w, h), Image.BILINEAR), np.float32) / 255
    rgb = rgb * (0.85 + 0.3 * noise[..., None])

    # dark line on each tile edge so every tile in an atlas stays distinguishable
    grid = ((xs % tile == 0) | (ys % tile == 0))[..., None]
    rgb = np.where(grid, rgb * 0.55, rgb)

    rgba = np.empty((h, w, 4), np.uint8)
    rgba[..., :3] = np.clip(rgb * 255, 0, 255).astype(np.uint8)
    rgba[..., 3] = 255 if source_alpha is None else source_alpha
    return Image.fromarray(rgba, "RGBA")


def svg_placeholder(path, data):
    import re
    text = data.decode(errors="replace")
    def attr(name, default):
        m = re.search(rf'<svg[^>]*\b{name}="([\d.]+)', text)
        return m.group(1) if m else default
    w, h = attr("width", "128"), attr("height", "128")
    r, g, b = (int(c * 255) for c in hsv_to_rgb(np.random.default_rng(seed_for(path)).random(), 0.55, 0.75))
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">'
            f'<rect width="100%" height="100%" fill="rgb({r},{g},{b})"/>'
            f'<path d="M0 0L{w} {h}M{w} 0L0 {h}" stroke="#0006" stroke-width="2"/></svg>\n').encode()


def placeholder_bytes(path, data, mode, tile=8):
    ext = os.path.splitext(path)[1].lower()
    if ext == ".svg":
        return svg_placeholder(path, data)
    src = Image.open(io.BytesIO(data))
    w, h = src.size
    alpha = None
    if mode == "silhouette" and src.mode in ("RGBA", "LA", "P", "PA"):
        alpha = np.asarray(src.convert("RGBA"))[..., 3]
    img = generate_rgba(path, w, h, alpha, tile)
    out = io.BytesIO()
    fmt = {".jpg": "JPEG", ".jpeg": "JPEG", ".webp": "WEBP", ".bmp": "BMP", ".tga": "TGA"}.get(ext, "PNG")
    if fmt == "JPEG":
        img = img.convert("RGB")
    img.save(out, fmt)
    return out.getvalue()


# --- shadow commit building ---------------------------------------------------

def load_keep_patterns(root):
    path = os.path.join(root, ".placeholderkeep")
    if not os.path.exists(path):
        return []
    with open(path) as f:
        return [l.strip() for l in f if l.strip() and not l.startswith("#")]


def is_kept(path, patterns):
    return any(fnmatch.fnmatch(path, p) for p in patterns)


class Cache:
    """Maps (source blob, path, mode) -> generated blob sha, stored inside .git."""

    def __init__(self, git_dir):
        self.file = os.path.join(git_dir, "placeholder-cache")
        self.map = {}
        if os.path.exists(self.file):
            with open(self.file) as f:
                for line in f:
                    k, v = line.rstrip("\n").split(" ", 1)
                    self.map[k] = v

    def save(self):
        with open(self.file, "w") as f:
            f.writelines(f"{k} {v}\n" for k, v in self.map.items())


def build_shadow_tree(commit, mode, tile, root, git_dir):
    keep = load_keep_patterns(root)
    cache = Cache(git_dir)
    out = git("ls-tree", "-r", "-z", commit).split(b"\0")
    updates, replaced = [], 0
    for entry in filter(None, out):
        meta, path = entry.split(b"\t", 1)
        file_mode, typ, sha = meta.decode().split()
        path = path.decode()
        if typ != "blob" or os.path.splitext(path)[1].lower() not in IMAGE_EXTS or is_kept(path, keep):
            continue
        key = hashlib.sha1(f"{GENERATOR_VERSION}:{mode}:{tile}:{sha}:{path}".encode()).hexdigest()
        new_sha = cache.map.get(key)
        if not new_sha or not rev_exists(new_sha):
            try:
                data = placeholder_bytes(path, git("cat-file", "blob", sha), mode, tile)
            except Exception as e:  # unreadable image: fall back to a 16x16 texture
                print(f"  warning: {path}: {e}; using 16x16 fallback", file=sys.stderr)
                buf = io.BytesIO()
                generate_rgba(path, 16, 16).save(buf, "PNG")
                data = buf.getvalue()
            new_sha = git_s("hash-object", "-w", "--stdin", input=data)
            cache.map[key] = new_sha
        updates.append(f"{file_mode} {new_sha}\t{path}")
        replaced += 1
    cache.save()

    with tempfile.TemporaryDirectory() as tmp:
        env = {**os.environ, "GIT_INDEX_FILE": os.path.join(tmp, "index")}
        git("read-tree", commit, env=env)
        if updates:
            git("update-index", "--index-info", input=("\n".join(updates) + "\n").encode(), env=env)
        tree = git_s("write-tree", env=env)
    return tree, replaced


def publish(args):
    root = git_s("rev-parse", "--show-toplevel")
    git_dir = git_s("rev-parse", "--absolute-git-dir")
    os.chdir(root)

    source = git_s("rev-parse", f"refs/heads/{args.branch}")
    shadow_ref = f"refs/placeholder/{args.branch}"
    remote_ref = f"refs/remotes/{args.remote}/{args.branch}"

    if args.fresh:
        parent = None
    elif rev_exists(shadow_ref):
        parent = git_s("rev-parse", shadow_ref)
    elif rev_exists(remote_ref):
        parent = git_s("rev-parse", remote_ref)  # first run: continue on top of what GitHub has
    else:
        parent = None

    if parent and source in git_s("log", "-1", "--format=%B", parent):
        print(f"{args.branch} @ {source[:7]} already has a placeholder commit.")
    else:
        print(f"Generating placeholder textures for {args.branch} @ {source[:7]} ({args.mode})...")
        tree, replaced = build_shadow_tree(source, args.mode, args.tile, root, git_dir)
        print(f"  {replaced} image(s) replaced")
        msg = git_s("log", "-1", "--format=%B", source)
        msg = f"{msg}\n\n{TRAILER} {source}\n"
        # keep original author/date so GitHub history reads naturally
        fmt = git_s("log", "-1", "--format=%an%x00%ae%x00%aI%x00%cn%x00%ce%x00%cI", source).split("\0")
        env = {**os.environ,
               "GIT_AUTHOR_NAME": fmt[0], "GIT_AUTHOR_EMAIL": fmt[1], "GIT_AUTHOR_DATE": fmt[2],
               "GIT_COMMITTER_NAME": fmt[3], "GIT_COMMITTER_EMAIL": fmt[4], "GIT_COMMITTER_DATE": fmt[5]}
        parent_args = ["-p", parent] if parent else []
        shadow = git_s("commit-tree", tree, *parent_args, "-F", "-", input=msg.encode(), env=env)
        git("update-ref", shadow_ref, shadow)
        print(f"  {shadow_ref} -> {shadow[:7]}")

    if args.dry_run:
        print(f"Dry run: not pushing. Inspect with: git show --stat {shadow_ref}")
        return
    push = ["push", "--no-verify", args.remote, f"{shadow_ref}:refs/heads/{args.branch}"]
    if args.fresh:
        push.insert(2, "--force-with-lease")
    print("Pushing:", "git", " ".join(push))
    res = subprocess.run(["git", *push])
    if res.returncode != 0:
        sys.exit(res.returncode)


def preview(args):
    data = git("show", f"HEAD:{args.path}")
    with open(args.out, "wb") as f:
        f.write(placeholder_bytes(args.path, data, args.mode, args.tile))
    print(f"wrote {args.out}")


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest="cmd", required=True)
    pub = sub.add_parser("publish")
    pub.add_argument("--branch", default="master")
    pub.add_argument("--remote", default="origin")
    pub.add_argument("--mode", choices=["procedural", "silhouette"], default="silhouette",
                     help="procedural: no source pixels used; silhouette: keep the original alpha mask")
    pub.add_argument("--fresh", action="store_true",
                     help="start a new history with no real art in it (force-pushes, rewrites GitHub history)")
    pub.add_argument("--dry-run", action="store_true")
    pub.add_argument("--tile", type=int, default=8, help="tile size in px the pattern is aligned to")
    pub.set_defaults(func=publish)
    pre = sub.add_parser("preview")
    pre.add_argument("path")
    pre.add_argument("out")
    pre.add_argument("--mode", choices=["procedural", "silhouette"], default="silhouette")
    pre.add_argument("--tile", type=int, default=8)
    pre.set_defaults(func=preview)
    args = p.parse_args()
    args.func(args)


if __name__ == "__main__":
    main()
