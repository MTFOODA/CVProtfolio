import assert from 'node:assert/strict';
import { test } from 'node:test';
import { handleShareMedia } from './index.ts';

const env = key => ({ SUPABASE_URL: 'https://backend.test', SUPABASE_ANON_KEY: 'anon', SUPABASE_SERVICE_ROLE_KEY: 'service' })[key];
const request = (resolver = 'resolve_share_with_password', params = { p_slug: 'portfolio', p_password: 'correct' }) =>
  new Request('https://function.test', { method: 'POST', body: JSON.stringify({ resolver, params }) });
const payload = {
  document: { ownerId: 'owner', includedProjectIds: ['p'], design: { sections: [{ kind: 'projects', visible: true, hiddenEntryIds: [] }] } },
  profile: { id: 'owner', details: {}, projects: [
    { id: 'p', media: ['owner/demo.mp4', 'another/private.png', 'owner/../secret.png'] },
    { id: 'hidden', visible: false, media: ['owner/hidden.mp4'] },
    { id: 'excluded', media: ['owner/excluded.png'] },
  ] },
};

test('wrong password, revoked, expired and unavailable shares never sign media', async () => {
  const calls = [];
  const response = await handleShareMedia(request(), env, async (url) => {
    calls.push(url); return Response.json(null);
  });
  assert.equal(response.status, 403);
  assert.equal(calls.length, 1);
  assert.match(calls[0], /rpc\/resolve_share_with_password$/);
});

test('only authorised visible owner paths are signed after password verification', async () => {
  const calls = [];
  const response = await handleShareMedia(request(), env, async (url, options) => {
    calls.push({ url, options });
    if (url.includes('/rpc/')) return Response.json(payload);
    return Response.json({ signedURL: '/object/sign/document-media/owner/demo.mp4?token=temporary' });
  });
  assert.equal(response.status, 200);
  const result = await response.json();
  assert.deepEqual(Object.keys(result.urls), ['owner/demo.mp4']);
  assert.equal(result.urls['owner/demo.mp4'], 'https://backend.test/storage/v1/object/sign/document-media/owner/demo.mp4?token=temporary');
  assert.equal(calls.length, 2);
  assert.equal(calls[0].options.headers.Authorization, 'Bearer anon');
  assert.equal(calls[1].options.headers.Authorization, 'Bearer service');
  assert.deepEqual(JSON.parse(calls[1].options.body), { expiresIn: 3600 });
  assert.equal(JSON.stringify(result).includes('service'), false);
});

test('hidden project section produces no signed project media', async () => {
  const hidden = structuredClone(payload);
  hidden.document.design.sections[0].visible = false;
  let calls = 0;
  const response = await handleShareMedia(request('resolve_share_by_token', { p_token: 'recipient-token' }), env, async () => {
    calls++; return Response.json(hidden);
  });
  assert.deepEqual(await response.json(), { urls: {} });
  assert.equal(calls, 1);
});

test('arbitrary RPCs and malformed credentials cannot use the service role', async () => {
  for (const [resolver, params] of [['load_private_profile', {}], ['__proto__', {}], ['resolve_share_by_slug', { p_slug: '' }]]) {
    const response = await handleShareMedia(request(resolver, params), env, async () => { throw Error('must not fetch'); });
    assert.equal(response.status, 400);
  }
});

test('storage errors do not fabricate success URLs or expose credentials', async () => {
  const response = await handleShareMedia(request(), env, async url => url.includes('/rpc/') ? Response.json(payload) : Response.json({ error: 'missing' }, { status: 404 }));
  assert.deepEqual(await response.json(), { urls: {} });
});

test('legacy private-bucket URLs are refreshed without trusting foreign origins or owners', async () => {
  const shared = structuredClone(payload);
  const old = 'https://backend.test/storage/v1/object/sign/document-media/owner/cover%20image.png?token=expired';
  const publicUrl = 'https://backend.test/storage/v1/object/public/document-media/owner/old.png';
  shared.profile.projects[0].media = [old, publicUrl,
    'https://other.test/storage/v1/object/public/document-media/owner/private.png',
    'https://backend.test/storage/v1/object/public/document-media/another/private.png',
    'https://backend.test/storage/v1/object/public/document-media/owner/a%2F..%2Fsecret.png'];
  const paths = [];
  const response = await handleShareMedia(request(), env, async url => {
    if (url.includes('/rpc/')) return Response.json(shared);
    paths.push(url);
    return Response.json({signedURL:'/object/sign/document-media/owner/fresh.png?token=fresh'});
  });
  const result = await response.json();
  assert.deepEqual(Object.keys(result.urls).sort(), [old, publicUrl].sort());
  assert.equal(paths.length, 2);
  assert.ok(paths.some(path => path.endsWith('/owner/cover%20image.png')));
});

for (const documentType of ['cv', 'portfolio']) {
test(`${documentType} signing uses its saved snapshot and excludes other CV media`, async () => {
  const shared = structuredClone(payload);
  shared.document.type = documentType;
  shared.document.profileSnapshot = {id:'owner', projects:[{id:'p', media:['owner/snapshot.png']}]};
  const calls = [];
  const response = await handleShareMedia(request(), env, async url => {
    calls.push(url);
    return url.includes('/rpc/') ? Response.json(shared)
      : Response.json({signedURL:'/object/sign/document-media/owner/snapshot.png?token=fresh'});
  });
  assert.deepEqual(Object.keys((await response.json()).urls), ['owner/snapshot.png']);
  assert.equal(calls.length, 2);
});
}



test('custom entry images require visible sections/entries and owner paths', async () => {
  for (const mode of ['default', 'visible', 'hidden-section', 'hidden-entry', 'invisible']) {
    const shared = structuredClone(payload);
    shared.profile.custom_sections = [{id:'extra', entries:[
      {id:'entry', imageUrl:'owner/certificate.png', visible:mode !== 'invisible'},
      {id:'foreign', imageUrl:'someone-else/private.png'},
      {id:'traversal', imageUrl:'owner/../someone-else/private.png'},
    ]}];
    if (mode !== 'default') shared.document.design.sections.push({
      kind:'custom', customSectionId:'extra', visible:mode !== 'hidden-section',
      hiddenEntryIds:mode === 'hidden-entry' ? ['entry'] : [],
    });
    const response = await handleShareMedia(request(), env, async url =>
      url.includes('/rpc/') ? Response.json(shared) : Response.json({signedURL:'/object/sign/document-media/owner/certificate.png?token=temporary'}));
    assert.equal(response.status,200);
    const result = await response.json();
    assert.equal(Boolean(result.urls['owner/certificate.png']), ['default','visible'].includes(mode));
    assert.equal(result.urls['someone-else/private.png'],undefined);
    assert.equal(result.urls['owner/../someone-else/private.png'],undefined);
  }
});
