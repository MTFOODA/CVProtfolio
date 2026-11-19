"""Read-only connection checks. Never prints keys or fetches user rows.

Usage: python tools/check_supabase.py [dart_defines.json]
"""

import json
import sys
import urllib.error
import urllib.request
import uuid
from pathlib import Path


def main():
    path = Path(sys.argv[1] if len(sys.argv) > 1 else 'dart_defines.json')
    config = json.loads(path.read_text(encoding='utf-8-sig'))
    origin = config['SUPABASE_URL'].rstrip('/')
    key = config['SUPABASE_ANON_KEY']
    headers = {'apikey': key, 'Authorization': f'Bearer {key}'}
    failures = []

    def check(label, route, expected=(200,), body=None, validate=None):
        request = urllib.request.Request(
            origin + route,
            headers={**headers, 'Content-Type': 'application/json'},
            data=None if body is None else json.dumps(body).encode(),
        )
        try:
            with urllib.request.urlopen(request, timeout=20) as response:
                status, raw = response.status, response.read().decode()
        except urllib.error.HTTPError as error:
            status, raw = error.code, error.read().decode()
        except (urllib.error.URLError, TimeoutError) as error:
            failures.append(label)
            print(f'FAIL {label}: {error}')
            return
        try:
            payload = json.loads(raw) if raw else None
        except ValueError:
            payload = None
        passed = status in expected and (validate is None or validate(payload))
        print(f'{"PASS" if passed else "FAIL"} {label}: HTTP {status}')
        if not passed:
            failures.append(label)
            if isinstance(payload, dict):
                # Error codes/messages describe schema availability, not rows.
                print('  ' + str(payload.get('code', '')) + ' ' +
                      str(payload.get('message', payload.get('error', ''))))
        return payload

    print(f'Project: {origin}')
    check('Auth health', '/auth/v1/health')
    settings = check('Auth settings', '/auth/v1/settings')
    if settings:
        print('  Google enabled:', settings.get('external', {}).get('google'))
        print('  Email enabled:', settings.get('external', {}).get('email'))
        print('  Email confirmation required:', not settings.get('mailer_autoconfirm', False))
    for table, columns in {
        'profiles': 'id,custom_sections',
        'documents': 'id,profile_snapshot,access_password_hash',
        'document_shares': 'id',
        'cv_builder_drafts': 'owner_id,draft_key,payload',
    }.items():
        # limit=0 checks table/column exposure without returning personal data.
        # Private tables may deny anon access even when deployed correctly.
        # This does not verify authenticated grants; exercise those after login.
        check(table, f'/rest/v1/{table}?select={columns}&limit=0',
              expected=(200, 401, 403),
              validate=lambda payload: payload == [] or
              (isinstance(payload, dict) and payload.get('code') == '42501'))
    missing = 'connection-audit-' + uuid.uuid4().hex
    for resolver, params in {
        'resolve_share_by_slug': {'p_slug': missing},
        'resolve_share_by_token': {'p_token': missing},
        'resolve_share_with_password': {'p_slug': missing, 'p_password': missing},
    }.items():
        check(resolver, f'/rest/v1/rpc/{resolver}', body=params,
              validate=lambda payload: payload is None)
    check('share-media deployed', '/functions/v1/share-media', expected=(403,),
          body={'resolver': 'resolve_share_by_slug', 'params': {'p_slug': missing}},
          validate=lambda payload: payload == {'error': 'Share unavailable'})
    print(f'{len(failures)} failed checks. No user rows were fetched or changed.')
    return 1 if failures else 0


if __name__ == '__main__':
    sys.exit(main())
