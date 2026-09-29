#!/usr/bin/env python3
"""Discovery check for Issue #17: install the loader from a ref into a throwaway HOME on
each host and print the host's own listing, anonymized. No model call.

  python3 discover.py <ref> [<ref> ...] > discovery.txt

Uses the confined setup of trigger_test.py (same directory); set BAS_REPO when this
file runs from a copy outside the checkout."""
import importlib.util
import json
import pathlib
import subprocess
import sys

spec = importlib.util.spec_from_file_location("t", pathlib.Path(__file__).with_name("trigger_test.py"))
t = importlib.util.module_from_spec(spec)
spec.loader.exec_module(t)


def sh(cmd, repo, env):
    r = subprocess.run(cmd, cwd=repo, env=env, stdin=subprocess.DEVNULL, capture_output=True, text=True, timeout=300)
    return r.returncode, r.stdout + r.stderr


def listing(host, repo, plugin, env):
    """[(command shown, relevant output lines)] for one host."""
    out = []
    if host == "claude":
        out.append(("claude plugin validate <plugin>", sh(["claude", "plugin", "validate", str(plugin)], repo, env)))
        code, text = sh(["claude", "--plugin-dir", str(plugin), "plugin", "list", "--json"], repo, env)
        try:
            text = json.dumps([p for p in json.loads(text) if p.get("scope") == "session"], indent=1)
        except ValueError:
            pass
        out.append(("claude --plugin-dir <plugin> plugin list --json (session plugins)", (code, text)))
        code, text = sh(["claude", "--plugin-dir", str(plugin), "plugin", "list"], repo, env)
        out.append(("claude --plugin-dir <plugin> plugin list (session section)",
                    (code, text.split("Synced from")[0])))
    elif host == "codex":
        code, text = sh(["codex", "plugin", "list"], repo, env)
        out.append(("codex plugin list (this plugin)", (code, "\n".join(l for l in text.splitlines()
                                                                         if "building-agentskills" in l))))
        code, text = sh(["codex", "debug", "prompt-input", "hi"], repo, env)
        blob = text.replace("\\n", "\n")
        lines = [l for l in blob.splitlines() if "building-agentskills" in l or l.startswith("- `r")]
        out.append(("codex debug prompt-input hi (Skill roots and the listed Skill)", (code, "\n".join(lines))))
    elif host == "grok":
        out.append(("grok plugin validate <plugin>", sh(["grok", "plugin", "validate", str(plugin)], repo, env)))
        out.append(("grok plugin list", sh(["grok", "plugin", "list"], repo, env)))
        code, text = sh(["grok", "inspect"], repo, env)
        section = text[text.find("Skills ("):text.find("Agents (")] if "Skills (" in text else text
        out.append(("grok inspect (Skills section)", (code, section)))
    else:
        code, text = sh(["opencode", "debug", "skill"], repo, env)
        try:
            text = "\n".join(f"{s['name']}: {s['location']}" for s in json.loads(text))
        except ValueError:
            pass
        out.append(("opencode debug skill (name: location)", (code, text)))
    return out


def main():
    for ref in sys.argv[1:]:
        arm = f"ref-{ref}"
        src = t.extract_sources({arm: ref})
        try:
            for host in ("claude", "codex", "grok", "opencode"):
                repo = home = None
                try:
                    repo = t.make_repo()
                    try:
                        home, plugin, env = t.make_home(host, arm, repo)
                        install = "installed"
                    except subprocess.CalledProcessError as error:
                        print(f"\n## {host} at {ref}: install failed ({error.cmd[:3]}, exit {error.returncode})")
                        continue
                    print(f"\n## {host} at {ref} ({t.SOURCES[arm + '-sha'][:7]}), {install}")
                    for shown, (code, text) in listing(host, repo, plugin, env):
                        print(f"\n$ {shown}\n(exit {code})\n" + t.anonymize(text.rstrip(), repo, plugin))
                finally:
                    t.remove(repo)
                    t.remove(home)
        finally:
            t.remove(src)


if __name__ == "__main__":
    main()
