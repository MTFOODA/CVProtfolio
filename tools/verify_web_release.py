"""Verify delivery of the local release on the existing Cloudflare host.

This checks HTTP delivery and SPA fallback, not browser interaction or real Auth.
"""

import hashlib
import json
from datetime import datetime, timezone
from pathlib import Path
from urllib.request import Request, urlopen


def main():
    origin = 'https://cvprotfolio.mohamed-fooda-mtf.workers.dev'
    checks = []
    local = Path('build/web')
    for route, kind in [
        ('/', 'text/html'),
        ('/about', 'text/html'),
        ('/p/release-verification-missing', 'text/html'),
        ('/s/release-verification-missing', 'text/html'),
        ('/flutter_bootstrap.js', 'javascript'),
        ('/main.dart.js', 'javascript'),
        ('/manifest.json', 'json'),
        ('/icons/Icon-192.png', 'image/png'),
        ('/icons/Icon-512.png', 'image/png'),
        ('/icons/Icon-maskable-192.png', 'image/png'),
        ('/icons/Icon-maskable-512.png', 'image/png'),
        ('/favicon.png', 'image/png'),
        ('/social-preview.png', 'image/png'),
        ('/assets/assets/branding/app_logo.png', 'image/png'),
    ]:
        request = Request(origin + route, headers={
            'User-Agent': 'CVPortfolio-Release-Verification/1.0',
            'Cache-Control': 'no-cache',
        })
        with urlopen(request, timeout=30) as response:
            data = response.read()
            content_type = response.headers.get_content_type()
            assert response.status == 200 and kind in content_type, (route, content_type)
            check = {'route': route, 'status': response.status, 'content_type': content_type, 'bytes': len(data)}
        if route in ('/', '/about', '/p/release-verification-missing', '/s/release-verification-missing'):
            assert data == (local / 'index.html').read_bytes(), f'Stale app shell: {route}'
        elif route == '/main.dart.js':
            digest = hashlib.sha256(data).hexdigest()
            assert digest == hashlib.sha256((local / 'main.dart.js').read_bytes()).hexdigest(), 'Hosted JS differs from this build'
            check['sha256'] = digest
        elif kind == 'image/png':
            assert data == (local / route.lstrip('/')).read_bytes(), f'Stale branding asset: {route}'
            check['sha256'] = hashlib.sha256(data).hexdigest()
        checks.append(check)
        print(f'PASS {route}: HTTP 200, {content_type}, {len(data)} bytes')
    report = {'origin': origin, 'verified_at_utc': datetime.now(timezone.utc).isoformat(), 'checks': checks}
    Path('build/flow-refinement-hosted-verification.json').write_text(json.dumps(report, indent=2), encoding='utf-8')


if __name__ == '__main__':
    main()
