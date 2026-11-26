#!/usr/bin/env python3
"""Tickets for Horion live in Plane (project HORION). This is the one command agents use for them.

  scripts/ticket.py list                               open tickets
  scripts/ticket.py show HORION-12                     title, state, path, text
  scripts/ticket.py new "<title>" [--path fix|visual|project] [--parent HORION-3] [--body "<text>"]
  scripts/ticket.py body HORION-12 <file>              replace the text with the file's contents
  scripts/ticket.py start HORION-12                    state: In Progress
  scripts/ticket.py done HORION-12                     state: Done (after the PR is merged)

The API token comes from $PLANE_TOKEN or ~/.plane_token. It is never printed.
Text: one paragraph per line; lines that start with "- " become a list.
"""
import html, json, os, re, sys, urllib.error, urllib.request

WORKSPACE, PROJECT = "luis-projects", "HORION"
API = f"https://api.plane.so/api/v1/workspaces/{WORKSPACE}"
WEB = f"https://app.plane.so/{WORKSPACE}"
PATHS = {"fix": "fix", "visual": "visual change", "project": "project"}


def token():
    t = os.environ.get("PLANE_TOKEN", "").strip()
    if not t:
        try:
            t = open(os.path.expanduser("~/.plane_token")).read().strip()
        except OSError:
            sys.exit("No Plane token: put it in ~/.plane_token or set PLANE_TOKEN.")
    return t


def call(method, path, body=None):
    req = urllib.request.Request(API + path, method=method,
                                 data=json.dumps(body).encode() if body is not None else None,
                                 headers={"X-API-Key": token(), "Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req) as r:
            return json.load(r)
    except urllib.error.HTTPError as e:
        sys.exit(f"Plane answered {e.code} for {method} {path}: {e.read().decode()[:300]}")


def rows(d):
    return d["results"] if isinstance(d, dict) else d


def project_id():
    for p in rows(call("GET", "/projects/")):
        if p["identifier"] == PROJECT:
            return p["id"]
    sys.exit(f"No Plane project {PROJECT} in workspace {WORKSPACE}.")


def by_name(pid, kind, name):
    for x in rows(call("GET", f"/projects/{pid}/{kind}/")):
        if x["name"].lower() == name.lower():
            return x["id"]
    sys.exit(f"Plane project {PROJECT} has no {kind[:-1]} named '{name}'.")


def item(key):
    if not re.fullmatch(rf"{PROJECT}-\d+", key):
        sys.exit(f"'{key}' is not a ticket key like {PROJECT}-12.")
    return call("GET", f"/work-items/{key}/?expand=state,labels")


def to_html(text):
    out, in_list = [], False
    for line in text.splitlines():
        line = line.strip()
        if line.startswith("- "):
            out.append(("" if in_list else "<ul>") + f"<li>{html.escape(line[2:])}</li>")
            in_list = True
            continue
        if in_list:
            out.append("</ul>")
            in_list = False
        if line:
            out.append(f"<p>{html.escape(line)}</p>")
    return "".join(out) + ("</ul>" if in_list else "")


def to_text(h):
    h = re.sub(r"<li[^>]*>", "- ", h or "")
    h = re.sub(r"</(p|li|h\d|div)>|<br ?/?>", "\n", h)
    return re.sub(r"\n{2,}", "\n", html.unescape(re.sub(r"<[^>]+>", "", h))).strip()


def name_of(x):
    return x["name"] if isinstance(x, dict) else str(x)


def line(i):
    labels = ", ".join(name_of(l) for l in i.get("labels") or [])
    return f"{PROJECT}-{i['sequence_id']}  [{name_of(i['state'])}]  {i['name']}" + (f"  ({labels})" if labels else "")


def set_state(key, name):
    pid = project_id()
    call("PATCH", f"/projects/{pid}/work-items/{item(key)['id']}/", {"state": by_name(pid, "states", name)})
    print(f"{key}: {name}")


def main(a):
    if not a or a[0] in ("-h", "--help"):
        sys.exit(__doc__)
    cmd, a = a[0], a[1:]
    if cmd == "list":
        pid = project_id()
        for i in sorted(rows(call("GET", f"/projects/{pid}/work-items/?expand=state,labels&per_page=100")),
                        key=lambda i: i["sequence_id"]):
            if isinstance(i["state"], dict) and i["state"].get("group") in ("completed", "cancelled"):
                continue
            print(line(i))
    elif cmd == "show" and len(a) == 1:
        i = item(a[0])
        print(line(i))
        print(f"{WEB}/browse/{a[0]}/")
        text = to_text(i.get("description_html"))
        if text:
            print("\n" + text)
    elif cmd == "new" and a:
        title, opts = a[0], dict(zip(a[1::2], a[2::2]))
        if len(a) % 2 == 0 or set(opts) - {"--path", "--parent", "--body"}:
            sys.exit(__doc__)
        pid = project_id()
        body = {"name": title}
        if "--path" in opts:
            if opts["--path"] not in PATHS:
                sys.exit("--path is one of: fix, visual, project")
            body["labels"] = [by_name(pid, "labels", PATHS[opts["--path"]])]
        if "--parent" in opts:
            body["parent"] = item(opts["--parent"])["id"]
        if "--body" in opts:
            body["description_html"] = to_html(opts["--body"])
        i = call("POST", f"/projects/{pid}/work-items/", body)
        key = f"{PROJECT}-{i['sequence_id']}"
        print(f"{key}  {WEB}/browse/{key}/")
    elif cmd == "body" and len(a) == 2:
        pid = project_id()
        call("PATCH", f"/projects/{pid}/work-items/{item(a[0])['id']}/", {"description_html": to_html(open(a[1]).read())})
        print(f"{a[0]}: text replaced")
    elif cmd == "start" and len(a) == 1:
        set_state(a[0], "In Progress")
    elif cmd == "done" and len(a) == 1:
        set_state(a[0], "Done")
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
