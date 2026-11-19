"""Real Supabase tests using an isolated, disposable account.

begin --email ADDRESS sends one confirmation email. verify runs after the user
confirms it. Credentials stay in git-ignored .dart_tool; never print tokens.
The verify phase creates and removes only its own synthetic records/files.
"""
import argparse
import json
import secrets
import urllib.error
import urllib.parse
import urllib.request
import uuid
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
STATE = ROOT / '.dart_tool/cv_auth_audit/credentials.json'
CONFIG = json.loads((ROOT / 'dart_defines.json').read_text(encoding='utf-8-sig'))
ORIGIN = CONFIG['SUPABASE_URL'].rstrip('/')
KEY = CONFIG['SUPABASE_ANON_KEY']


def request(route, method='GET', body=None, token=None, extra=None):
    headers = {'apikey': KEY, 'Authorization': 'Bearer ' + (token or KEY)}
    if extra:
        headers.update(extra)
    if isinstance(body, bytes):
        data = body
    elif body is not None:
        data = json.dumps(body).encode()
        headers['Content-Type'] = 'application/json'
    else:
        data = None
    url = route if route.startswith('https://') else ORIGIN + route
    # Signed media URLs need no authorization header.
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=25) as response:
            status, raw = response.status, response.read()
    except urllib.error.HTTPError as error:
        status, raw = error.code, error.read()
    try:
        payload = json.loads(raw)
    except (ValueError, UnicodeDecodeError):
        payload = raw
    return status, payload


def require(label, actual, expected, payload=None):
    if actual not in expected:
        code = payload.get('code', payload.get('error_code', '')) if isinstance(payload, dict) else ''
        raise RuntimeError(f'{label}: HTTP {actual} ({code})')
    print(f'PASS {label}: HTTP {actual}')


def login(state):
    status, payload = request('/auth/v1/token?grant_type=password', 'POST', {
        'email': state['email'], 'password': state['password'],
    })
    require('password sign-in after confirmation', status, (200,), payload)
    if payload['user']['id'] != state['user_id']:
        raise RuntimeError('Unexpected account returned; refusing fixture operations')
    return payload


def begin(email):
    if STATE.exists():
        raise RuntimeError('A test account is already pending; use verify instead of sending another email')
    state = {'email': email, 'password': secrets.token_urlsafe(32), 'fixture_id': str(uuid.uuid4())}
    status, payload = request('/auth/v1/signup?redirect_to=http%3A%2F%2Flocalhost%3A8080%2F', 'POST', {
        'email': email, 'password': state['password'],
        'data': {'full_name': 'Disposable Authentication Audit'},
    })
    require('signup accepted', status, (200,), payload)
    user = payload.get('user', payload)
    if not user.get('id') or user.get('identities') == []:
        raise RuntimeError('Signup did not create a new identifiable account')
    state['user_id'] = user['id']
    STATE.parent.mkdir(parents=True, exist_ok=True)
    STATE.write_text(json.dumps(state), encoding='utf-8')
    print('Confirmation email requested for:', email)
    print('Awaiting the user clicking its confirmation link. No password or token was logged.')


def verify():
    state = json.loads(STATE.read_text(encoding='utf-8'))
    session = login(state)
    uid, fixture = state['user_id'], state['fixture_id']
    access, refresh = session['access_token'], session['refresh_token']
    media = f'{uid}/auth-audit-{fixture}.txt'
    token = secrets.token_urlsafe(32)
    slug = 'auth-audit-' + fixture
    profile = {'id': uid, 'details': {'fullName': 'Disposable Authentication Audit'}}
    try:
        status, data = request('/auth/v1/user', token=access)
        require('server validates session user', status, (200,), data)
        if not data.get('email_confirmed_at'):
            raise RuntimeError('Email is not confirmed')
        print('PASS email_confirmed_at present')
        status, data = request('/auth/v1/token?grant_type=password', 'POST', {
            'email': state['email'], 'password': 'deliberately-wrong-' + secrets.token_urlsafe(16),
        })
        require('wrong password rejected', status, (400, 401), data)
        status, data = request('/rest/v1/profiles', 'POST', profile, access,
                               {'Prefer': 'resolution=merge-duplicates,return=representation'})
        require('authenticated profile save', status, (200, 201), data)
        status, data = request(f'/rest/v1/profiles?id=eq.{uid}&select=id,details', token=access)
        require('authenticated profile read', status, (200,), data)
        if len(data) != 1 or data[0]['details'] != profile['details']:
            raise RuntimeError('Profile did not round-trip')
        status, data = request(f'/rest/v1/profiles?id=eq.{uid}&select=id')
        require('anonymous profile access', status, (200, 401, 403), data)
        if status == 200 and data:
            raise RuntimeError('Anonymous user can read a private profile')
        other = str(uuid.uuid4())
        status, data = request('/rest/v1/profiles', 'POST', {'id': other, 'details': {}}, access)
        require('cross-owner profile insert rejected', status, (401, 403), data)
        status, data = request('/rest/v1/documents', 'POST', {
            'id': fixture, 'owner_id': uid, 'title': 'Disposable auth audit',
            'type': 'portfolio', 'published': True, 'share_mode': 'publicLink',
            'public_slug': slug,
        }, access)
        require('authenticated document save', status, (201,), data)
        status, data = request('/rest/v1/cv_builder_drafts', 'POST', {
            'owner_id': uid, 'draft_key': fixture, 'payload': {'profile': profile},
        }, access)
        require('authenticated CV draft save', status, (201,), data)
        status, data = request('/rest/v1/document_shares', 'POST', [
            {'document_id': fixture, 'mode': 'publicLink', 'slug': slug, 'access_token': None},
            {'document_id': fixture, 'mode': 'restrictedRecipient', 'slug': None, 'access_token': token},
        ], access)
        require('authenticated share save', status, (201,), data)
        def rpc(name, params, expected_data=None, caller=None):
            status, result = request('/rest/v1/rpc/' + name, 'POST', params, caller)
            require(name, status, (200, 204), result)
            if expected_data == 'document' and (not isinstance(result, dict) or result.get('document', {}).get('id') != fixture):
                raise RuntimeError(name + ' did not resolve its document')
            if expected_data == 'denied' and result is not None:
                raise RuntimeError(name + ' bypassed authorization')
            return result
        rpc('resolve_share_by_slug', {'p_slug': slug}, 'document')
        rpc('resolve_share_by_token', {'p_token': token}, 'document')
        rpc('set_portfolio_password', {'p_document_id': fixture, 'p_password': 'audit-password'}, caller=access)
        rpc('resolve_share_by_slug', {'p_slug': slug}, 'denied')
        for password in (None, '', 'wrong'):
            rpc('resolve_share_with_password', {'p_slug': slug, 'p_password': password}, 'denied')
        rpc('resolve_share_with_password', {'p_slug': slug, 'p_password': 'audit-password'}, 'document')
        blob = b'Disposable authentication audit media'
        status, data = request('/storage/v1/object/document-media/' + media, 'POST', blob, access,
                               {'Content-Type': 'text/plain'})
        require('private storage upload', status, (200,), data)
        status, data = request('/storage/v1/object/sign/document-media/' + media, 'POST', {'expiresIn': 60}, access)
        require('owner media signing', status, (200,), data)
        signed_url = ORIGIN + '/storage/v1' + data['signedURL']
        status, content = request(signed_url)
        require('signed media download', status, (200,), content)
        if content != blob:
            raise RuntimeError('Signed media contents differ')
        status, data = request('/storage/v1/object/public/document-media/' + media)
        require('unsigned public media access rejected', status, (400, 401, 403, 404), data)
        status, data = request('/auth/v1/token?grant_type=refresh_token', 'POST', {'refresh_token': refresh})
        require('session refresh', status, (200,), data)
        access, refresh = data['access_token'], data['refresh_token']
        status, data = request('/auth/v1/user', token=access)
        require('refreshed session accepted', status, (200,), data)
        new_password = secrets.token_urlsafe(32)
        status, data = request('/auth/v1/user', 'PUT', {'password': new_password}, access)
        require('authenticated password update', status, (200,), data)
        status, data = request('/auth/v1/token?grant_type=password', 'POST', {
            'email': state['email'], 'password': state['password'],
        })
        require('old password rejected after update', status, (400, 401), data)
        state['password'] = new_password
        STATE.write_text(json.dumps(state), encoding='utf-8')
        session = login(state)
        access, refresh = session['access_token'], session['refresh_token']
    finally:
        # Clean only the fixtures created for this isolated account.
        for route, method, body in [
            ('/storage/v1/object/document-media', 'DELETE', {'prefixes': [media]}),
            (f'/rest/v1/documents?id=eq.{fixture}&owner_id=eq.{uid}', 'DELETE', None),
            (f'/rest/v1/cv_builder_drafts?owner_id=eq.{uid}&draft_key=eq.{fixture}', 'DELETE', None),
            (f'/rest/v1/profiles?id=eq.{uid}', 'DELETE', None),
        ]:
            status, payload = request(route, method, body, access)
            require('fixture cleanup', status, (200, 204), payload)
    status, data = request('/auth/v1/logout', 'POST', token=access)
    require('sign-out', status, (200, 204), data)
    status, data = request('/auth/v1/token?grant_type=refresh_token', 'POST', {'refresh_token': refresh})
    require('signed-out refresh token rejected', status, (400, 401), data)
    print('PASS complete live email authentication/data/storage audit; synthetic fixtures removed')


def cleanup():
    state = json.loads(STATE.read_text(encoding='utf-8'))
    if '+cv-audit-' not in state['email']:
        raise RuntimeError('Refusing to remove an account outside the disposable audit alias')
    session = login(state)
    access = session['access_token']
    status, data = request('/auth/v1/logout', 'POST', token=access)
    require('revoke disposable account sessions', status, (200, 204), data)
    status, data = request('/rest/v1/rpc/delete_own_account', 'POST', {}, access)
    require('remove disposable audit account', status, (200, 204), data)
    STATE.unlink()
    print('PASS disposable account and local generated credentials removed')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('phase', choices=['begin', 'verify', 'cleanup'])
    parser.add_argument('--email')
    args = parser.parse_args()
    try:
        if args.phase == 'begin':
            if not args.email:
                parser.error('--email is required for begin')
            begin(args.email)
        elif args.phase == 'verify':
            verify()
        else:
            cleanup()
    except Exception as error:
        # Request errors must never print request bodies or authorization headers.
        print('BLOCKED:', str(error))
        raise SystemExit(1)
