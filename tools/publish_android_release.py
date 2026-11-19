"""Publish the requested public APK download using the existing Git login.

Credentials remain in memory; neither tokens nor credential-helper output are
written to logs. Existing published assets are never replaced by this helper.
"""

import argparse
import hashlib
import json
import subprocess
from pathlib import Path
from urllib.error import HTTPError
from urllib.request import Request, urlopen


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--publish', action='store_true')
    args = parser.parse_args()
    apk = Path('build/app/outputs/flutter-apk/app-release.apk')
    raw = apk.read_bytes()
    assert raw.startswith(b'PK'), 'Expected a built APK ZIP package'
    digest = hashlib.sha256(raw).hexdigest()
    version = next(line.split(':', 1)[1].strip() for line in Path('pubspec.yaml').read_text().splitlines() if line.startswith('version:'))
    tag = 'v' + version.split('+')[0]
    repo = 'MTFOODA/CVProtfolio'
    asset_name = 'cv-portfolio-builder.apk'
    credentials = subprocess.run(
        ['git', '-c', 'credential.interactive=false', 'credential', 'fill'],
        input='protocol=https\nhost=github.com\nusername=MTFOODA\n\n',
        text=True, capture_output=True, check=True,
    )
    fields = dict(line.split('=', 1) for line in credentials.stdout.splitlines() if '=' in line)
    token = fields['password']

    def api(path, data=None, method=None, binary=False):
        url = path if path.startswith('https://uploads.github.com/') else 'https://api.github.com' + path
        request = Request(url, method=method, data=data if binary or data is None else json.dumps(data).encode(), headers={
            'Authorization': 'Bearer ' + token,
            'User-Agent': 'CVPortfolio-Release/1.0',
            'Accept': 'application/vnd.github+json',
            'Content-Type': 'application/vnd.android.package-archive' if binary else 'application/json',
        })
        with urlopen(request, timeout=120) as response:
            return json.load(response)

    try:
        release = api(f'/repos/{repo}/releases/tags/{tag}')
    except HTTPError as error:
        if error.code != 404:
            raise
        release = api(f'/repos/{repo}/releases', {
            'tag_name': tag,
            'target_commitish': 'main',
            'name': f'CV & Portfolio Builder — Android {version}',
            'draft': True,
            'prerelease': False,
            'body': (
                'Direct Android APK download for CV & Portfolio Builder.\n\n'
                f'Version: {version}\n\nSHA-256: `{digest}`\n\n'
                'Applies the approved modern CV monogram to the application and platform icons. '
                'Includes the simplified Home screen and the CV preview state fix from 1.0.3. '
                'Existing portfolio pages, sharing and exports are retained.\n\n'
                'Build provenance: compiled from the current local development workspace. '
                'The Git tag identifies the repository baseline; the APK also includes local '
                'changes that have not yet been committed to that baseline. '
                'The project\'s existing Android signing configuration is retained.'
            ),
        }, 'POST')
    asset = next((item for item in release['assets'] if item['name'] == asset_name), None)
    if asset is None:
        assert release['draft'], 'Refusing to change assets of a published release'
        upload = release['upload_url'].split('{', 1)[0] + '?name=' + asset_name
        asset = api(upload, raw, 'POST', binary=True)
    assert asset['state'] == 'uploaded' and asset['size'] == len(raw)
    assert asset.get('digest') == 'sha256:' + digest, 'Remote artifact does not match this APK'
    if args.publish and release['draft']:
        release = api(f'/repos/{repo}/releases/{release["id"]}', {'draft': False, 'make_latest': 'true'}, 'PATCH')
        asset = next(item for item in release['assets'] if item['name'] == asset_name)
    report = {
        'release_url': release['html_url'], 'tag': tag, 'draft': release['draft'],
        'download_url': asset['browser_download_url'], 'bytes': len(raw), 'sha256': digest,
    }
    Path('build/about-android-release.json').write_text(json.dumps(report, indent=2), encoding='utf-8')
    print(json.dumps(report, indent=2))


if __name__ == '__main__':
    main()
