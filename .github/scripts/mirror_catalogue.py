"""Mirror the latest stable release catalogue verbatim for browser delivery.

Only the generated web-catalogue branch is written. No release or source edits.
"""

import base64
import hashlib
import json
import os
import re
import urllib.error
import urllib.request


BRANCH = "web-catalogue"


def validate_catalogue(release, asset, data):
    if release.get("draft") or release.get("prerelease"):
        raise ValueError("Only a published stable release can be mirrored")
    tag = release["tag_name"]
    if not re.fullmatch(r"content-v\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?", tag):
        raise ValueError("Unexpected content tag")
    if len(data) != asset["size"]:
        raise ValueError("Catalogue size mismatch")
    digest = "sha256:" + hashlib.sha256(data).hexdigest()
    if asset.get("digest") != digest:
        raise ValueError("Catalogue SHA-256 missing or mismatched")
    catalogue = json.loads(data)
    navigation = catalogue.get("navigation")
    if not isinstance(navigation, list) or not navigation:
        raise ValueError("Missing generated navigation (not a release catalogue)")
    for module in navigation:
        if not module.get("id") or not isinstance(module.get("units"), list):
            raise ValueError("Malformed generated module")
    return catalogue


class GitHub:
    def __init__(self, repo, token):
        self.base = "https://api.github.com/repos/" + repo
        self.token = token

    def __call__(self, path, method="GET", body=None):
        request = urllib.request.Request(
            self.base + path,
            data=None if body is None else json.dumps(body).encode(),
            method=method,
            headers={
                "Authorization": "Bearer " + self.token,
                "Accept": "application/vnd.github+json",
                "X-GitHub-Api-Version": "2022-11-28",
                "Content-Type": "application/json",
                "User-Agent": "EntrApprendre-catalogue-mirror",
            },
        )
        with urllib.request.urlopen(request, timeout=60) as response:
            return json.load(response)


def mirror(api, download, repo):
    release = api("/releases/latest")
    assets = [a for a in release["assets"] if a["name"] == "catalog.json"]
    if len(assets) != 1:
        raise ValueError("Expected exactly one catalogue release asset")
    asset = assets[0]
    expected_url = (
        f"https://github.com/{repo}/releases/download/"
        f"{release['tag_name']}/catalog.json"
    )
    if asset["browser_download_url"] != expected_url:
        raise ValueError("Unexpected catalogue download URL")
    data = download(expected_url)
    catalogue = validate_catalogue(release, asset, data)
    # Hash Git's byte-identical blob, rather than reserializing JSON.
    blob_sha = hashlib.sha1(
        b"blob " + str(len(data)).encode() + b"\0" + data
    ).hexdigest()
    parent = None
    try:
        parent = api(f"/git/ref/heads/{BRANCH}")["object"]["sha"]
    except urllib.error.HTTPError as error:
        if error.code != 404:
            raise
    if parent:
        tree_sha = api(f"/git/commits/{parent}")["tree"]["sha"]
        tree = api(f"/git/trees/{tree_sha}")["tree"]
        if len(tree) != 1 or tree[0]["path"] != "catalog.json":
            raise ValueError("Mirror branch has unexpected files; refusing overwrite")
        if tree[0]["sha"] == blob_sha:
            return "Catalogue already current: " + release["tag_name"]
    blob = api("/git/blobs", "POST", {
        "content": base64.b64encode(data).decode(), "encoding": "base64"
    })
    if blob["sha"] != blob_sha:
        raise ValueError("Uploaded blob hash mismatch")
    tree = api("/git/trees", "POST", {"tree": [{
        "path": "catalog.json", "mode": "100644", "type": "blob", "sha": blob_sha
    }]})
    commit = api("/git/commits", "POST", {
        "message": f"Mirror verified catalogue from {release['tag_name']}",
        "tree": tree["sha"], "parents": [parent] if parent else []
    })
    # Do not switch the public pointer if latest changed while downloading.
    latest = api("/releases/latest")
    if latest["id"] != release["id"] or latest.get("prerelease") or latest.get("draft"):
        raise ValueError("Stable release changed during sync; rerun")
    if parent:
        api(f"/git/refs/heads/{BRANCH}", "PATCH", {
            "sha": commit["sha"], "force": False
        })
    else:
        api("/git/refs", "POST", {
            "ref": f"refs/heads/{BRANCH}", "sha": commit["sha"]
        })
    return f"Mirrored {release['tag_name']}: {len(catalogue['navigation'])} modules"


def download(url):
    # Deliberately no GitHub credentials on asset/CDN requests.
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


if __name__ == "__main__":
    repository = os.environ["GITHUB_REPOSITORY"]
    print(mirror(GitHub(repository, os.environ["GH_TOKEN"]), download, repository))
