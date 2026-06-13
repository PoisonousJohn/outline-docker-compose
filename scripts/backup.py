#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request
from datetime import date
from pathlib import Path

PROJECT_DIR = Path(__file__).resolve().parent.parent
YADISK_API = "https://cloud-api.yandex.net/v1/disk/resources/upload"


def run(cmd, **kwargs):
    print(f"+ {' '.join(cmd)}")
    result = subprocess.run(cmd, **kwargs)
    if result.returncode != 0:
        raise RuntimeError(f"Command failed with exit code {result.returncode}: {' '.join(cmd)}")


def get_upload_url(token: str, remote_name: str) -> str:
    params = urllib.parse.urlencode({"path": remote_name, "overwrite": "true"})
    req = urllib.request.Request(
        f"{YADISK_API}?{params}",
        headers={"Authorization": f"OAuth {token}"},
    )
    with urllib.request.urlopen(req) as resp:
        data = json.loads(resp.read())
    return data["href"]


def upload_file(upload_url: str, local_path: Path):
    with open(local_path, "rb") as f:
        req = urllib.request.Request(upload_url, data=f, method="PUT")
        req.add_header("Content-Length", str(local_path.stat().st_size))
        try:
            urllib.request.urlopen(req)
        except urllib.error.HTTPError as e:
            raise RuntimeError(f"Upload failed: HTTP {e.code} {e.reason}")


def main():
    parser = argparse.ArgumentParser(description="Backup project to Yandex Disk")
    parser.add_argument("--password", required=True, help="ZIP archive password")
    parser.add_argument("--token", required=True, help="Yandex Disk OAuth token")
    parser.add_argument("--source", default=str(PROJECT_DIR), help="Path to archive (default: project root)")
    args = parser.parse_args()

    today = date.today().strftime("%Y-%m-%d")
    archive_name = f"backup{today}.zip"
    remote_name = f"backups/backup{today}.zip.upload"
    archive_path = Path(tempfile.gettempdir()) / archive_name

    print("Stopping services...")
    run(["make", "-C", str(PROJECT_DIR), "stop"])

    try:
        print(f"Creating archive: {archive_path}")
        run(["zip", "-r", "-P", args.password, str(archive_path), "."], cwd=args.source)

        print(f"Uploading to Yandex Disk as {remote_name} ...")
        upload_url = get_upload_url(args.token, remote_name)
        upload_file(upload_url, archive_path)

        print(f"Upload complete. Removing {archive_path}")
        archive_path.unlink()
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        print("Starting services...")
        run(["make", "-C", str(PROJECT_DIR), "start"])

    print("Done.")


if __name__ == "__main__":
    main()
