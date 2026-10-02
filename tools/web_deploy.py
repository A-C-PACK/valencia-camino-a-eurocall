"""Publish the web build to GitHub Pages.

    python -X utf8 tools/web_build.py       # make web/ first
    python -X utf8 tools/web_deploy.py      # then push it to the gh-pages branch

The site is served from a separate `gh-pages` branch that holds nothing but the
contents of web/, replaced wholesale on each deploy (the branch keeps no
history, so the 40 MB engine file is not stored again every time). The main
branch never contains the build.

An optional argument names a text file to use as the commit message.
"""

import pathlib
import shutil
import subprocess
import sys
import tempfile

ROOT = pathlib.Path(__file__).resolve().parent.parent
WEB = ROOT / "web"


def git(*args, cwd):
    r = subprocess.run(["git", *args], cwd=cwd, capture_output=True, text=True, encoding="utf-8")
    if r.returncode:
        sys.exit(f"git {' '.join(args)} failed:\n{r.stderr.strip()}")
    return r.stdout.strip()


def main():
    if not (WEB / "index.html").exists():
        sys.exit("web/index.html is missing: run tools/web_build.py first")
    remote = git("remote", "get-url", "origin", cwd=ROOT)
    name = git("config", "user.name", cwd=ROOT)
    email = git("config", "user.email", cwd=ROOT)
    message = "Deploy web build"
    if len(sys.argv) > 1:
        message = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")

    with tempfile.TemporaryDirectory() as tmp:
        site = pathlib.Path(tmp) / "site"
        shutil.copytree(WEB, site)
        # Tell Pages to serve the files as they are, without running Jekyll.
        (site / ".nojekyll").write_text("", encoding="utf-8")
        git("init", "-q", "-b", "gh-pages", cwd=site)
        git("config", "user.name", name, cwd=site)
        git("config", "user.email", email, cwd=site)
        git("add", "-A", cwd=site)
        git("commit", "-q", "-m", message, cwd=site)
        git("push", "--force", remote, "gh-pages", cwd=site)
    size = sum(f.stat().st_size for f in WEB.iterdir()) / 1e6
    print(f"deployed {size:.1f} MB to the gh-pages branch of {remote}")


if __name__ == "__main__":
    main()
