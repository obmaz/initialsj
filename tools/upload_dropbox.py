#!/usr/bin/env python3
"""Upload one file to Dropbox and print its direct-download link.

    python3 tools/upload_dropbox.py build/android/initialsj-debug.apk --name initialsj-test.apk

Credentials come from the environment, never from the repository. Use a refresh token (it does not
expire, the script exchanges it for a short-lived access token on every run):

    DROPBOX_APP_KEY, DROPBOX_APP_SECRET, DROPBOX_REFRESH_TOKEN

or, for a quick manual run, a ready access token in DROPBOX_ACCESS_TOKEN. The Dropbox app needs the
`files.content.write` scope, plus `sharing.write` when you want a link (otherwise use --no-link).

The file is stored at <dest-dir>/<name> (default /initialsj/<file name>) and replaced in place, so the
shared link stays the same across uploads. With an "App folder" app the path is relative to that
folder. Only the Python standard library is used.
"""
import argparse
import hashlib
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request

API = "https://api.dropboxapi.com"
CONTENT = "https://content.dropboxapi.com"
SINGLE_UPLOAD_LIMIT = 100 * 1024 * 1024  # /files/upload accepts up to 150 MiB; stay well below it.
CHUNK = 8 * 1024 * 1024


class DropboxError(RuntimeError):
    pass


def request(url, data=None, headers=None, timeout=300):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as response:
            return response.read()
    except urllib.error.HTTPError as error:
        body = error.read().decode("utf-8", "replace")[:600]
        raise DropboxError(f"{url.split('?')[0]} -> HTTP {error.code}: {body}") from None
    except urllib.error.URLError as error:
        raise DropboxError(f"{url.split('?')[0]} -> {error.reason}") from None


def access_token():
    token = os.environ.get("DROPBOX_ACCESS_TOKEN", "").strip()
    if token:
        return token
    values = {name: os.environ.get(name, "").strip() for name in ("DROPBOX_APP_KEY", "DROPBOX_APP_SECRET", "DROPBOX_REFRESH_TOKEN")}
    missing = [name for name, value in values.items() if not value]
    if missing:
        raise DropboxError("Set DROPBOX_APP_KEY, DROPBOX_APP_SECRET and DROPBOX_REFRESH_TOKEN (or DROPBOX_ACCESS_TOKEN). Missing: " + ", ".join(missing))
    form = urllib.parse.urlencode({
        "grant_type": "refresh_token",
        "refresh_token": values["DROPBOX_REFRESH_TOKEN"],
        "client_id": values["DROPBOX_APP_KEY"],
        "client_secret": values["DROPBOX_APP_SECRET"],
    }).encode()
    reply = json.loads(request(API + "/oauth2/token", form, {"Content-Type": "application/x-www-form-urlencoded"}))
    return reply["access_token"]


def rpc(token, endpoint, payload):
    body = request(API + endpoint, json.dumps(payload).encode(), {"Authorization": "Bearer " + token, "Content-Type": "application/json"})
    return json.loads(body) if body else {}


def content_call(token, endpoint, arg, data):
    headers = {
        "Authorization": "Bearer " + token,
        "Content-Type": "application/octet-stream",
        # Non-ASCII is escaped by json.dumps, which the Dropbox-API-Arg header requires.
        "Dropbox-API-Arg": json.dumps(arg),
    }
    body = request(CONTENT + endpoint, data, headers)
    return json.loads(body) if body else {}


def upload(token, source, dest):
    commit = {"path": dest, "mode": "overwrite", "autorename": False, "mute": True}
    size = os.path.getsize(source)
    with open(source, "rb") as handle:
        if size <= SINGLE_UPLOAD_LIMIT:
            return content_call(token, "/2/files/upload", commit, handle.read())
        session = content_call(token, "/2/files/upload_session/start", {"close": False}, handle.read(CHUNK))["session_id"]
        offset = min(size, CHUNK)
        while size - offset > CHUNK:
            cursor = {"session_id": session, "offset": offset}
            content_call(token, "/2/files/upload_session/append_v2", {"cursor": cursor, "close": False}, handle.read(CHUNK))
            offset += CHUNK
        cursor = {"session_id": session, "offset": offset}
        return content_call(token, "/2/files/upload_session/finish", {"cursor": cursor, "commit": commit}, handle.read())


def shared_link(token, path):
    try:
        link = rpc(token, "/2/sharing/create_shared_link_with_settings", {"path": path})["url"]
    except DropboxError as error:
        if "shared_link_already_exists" not in str(error):
            raise
        link = rpc(token, "/2/sharing/list_shared_links", {"path": path, "direct_only": True})["links"][0]["url"]
    # dl=1 makes the link download the file directly instead of opening Dropbox's preview page.
    parts = urllib.parse.urlsplit(link)
    query = [(key, value) for key, value in urllib.parse.parse_qsl(parts.query, keep_blank_values=True) if key not in ("dl", "raw")]
    query.append(("dl", "1"))
    return urllib.parse.urlunsplit(parts._replace(query=urllib.parse.urlencode(query)))


def content_hash(source):
    """Dropbox content_hash: SHA-256 of the SHA-256 of each 4 MiB block."""
    block_hashes = b""
    with open(source, "rb") as handle:
        while block := handle.read(4 * 1024 * 1024):
            block_hashes += hashlib.sha256(block).digest()
    return hashlib.sha256(block_hashes).hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("file", help="local file to upload")
    parser.add_argument("--name", help="file name in Dropbox (default: the local file name)")
    parser.add_argument("--dest-dir", default="/initialsj", help="Dropbox folder (default: /initialsj)")
    parser.add_argument("--no-link", action="store_true", help="skip creating the shared link")
    args = parser.parse_args()
    if not os.path.isfile(args.file):
        sys.exit(f"File not found: {args.file}")
    name = args.name or os.path.basename(args.file)
    dest = "/" + args.dest_dir.strip("/") + "/" + name if args.dest_dir.strip("/") else "/" + name
    try:
        token = access_token()
        metadata = upload(token, args.file, dest)
        if metadata.get("content_hash") != content_hash(args.file):
            raise DropboxError("Dropbox reports a different content hash than the local file; the upload is not trustworthy.")
        print(f"Uploaded {args.file} ({metadata['size'] / 1048576:.1f} MiB) to {metadata['path_display']}, content hash verified.")
        if not args.no_link:
            print("Download link: " + shared_link(token, metadata["path_lower"]))
    except DropboxError as error:
        sys.exit(f"Dropbox upload failed: {error}")


if __name__ == "__main__":
    main()
