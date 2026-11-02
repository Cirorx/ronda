// Every admin-only path under firestore.rules, in one table (#69): the app shows the Admin tab
// from the ID token's `admin` claim, but that is only what the app shows. Here each admin path
// is read by the admin claim (`admin: true`, exactly) and by nobody else: not signed out, not a
// member of the ronda it is about, and not a token whose claim only looks like it (`false`,
// `'true'`, `1`, `'yes'`, a `role`). No client writes any of them, the admin included. And the
// claim opens nothing in Storage, which has no admin path.
//
//   cd rules && npm install && npm run test:emulator
//
// It runs on its own project id, like the other files.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';
import { getBytes, ref, uploadBytes } from 'firebase/storage';

const NOW = new Date('2026-11-05T20:00:00Z');
const WEEK = '2026-W45';
const MEMBER = 'demo-admin-member';
const RUN = 'demo-run';

// Each admin path, written the way the functions write it (with the admin SDK), and whether a
// client may list its collection (rolls are `get` only, for everyone).
const ADMIN_PATHS = [
  { path: 'proposals/p1', fields: { status: 'pending', groups: [], createdAt: NOW } },
  { path: 'seguimos_counts/r1', fields: { si: 3, no: 1, sinContestar: 1 } },
  { path: `agent_runs/${RUN}`, fields: { job: 'rain', status: 'done', startedAt: NOW } },
  { path: `agent_runs/${RUN}/steps/001`, fields: { n: 1, by: 'code' } },
  { path: `acta/r1/flags/${MEMBER}`, fields: { week: WEEK, at: NOW } },
  { path: `rondas/r1/weeks/${WEEK}`, fields: { rsvp: { [MEMBER]: 'yes' }, attendance: {} } },
  {
    path: `rondas/r1/rolls/${WEEK}`,
    fields: { week: WEEK, people: [], marks: {}, askedUid: 'demo-admin-host' },
    getOnly: true,
  },
  { path: 'client_errors/e1', fields: { code: 'x', at: NOW } },
  {
    path: 'reports/rep1',
    fields: { reporterUid: MEMBER, aboutUid: 'demo-admin-host', text: 'x', unread: true },
  },
  { path: `avoid/demo-admin-host_${MEMBER}`, fields: { uidA: 'demo-admin-host', uidB: MEMBER } },
  { path: 'removed/demo-admin-host', fields: { firstName: 'Mirta', at: NOW, notice: 'sent' } },
];

// Stored files a member might upload or the functions publish: the claim reads none of them.
const STORED = [
  `audio/${MEMBER}/note.wav`,
  `flyer_photos/${MEMBER}/photo.jpg`,
  `donde_queda_photos/${MEMBER}/photo.jpg`,
  `donde_queda/r1/photo.jpg`,
  `flyers/${MEMBER}/flyer.jpg`,
];

let env;

before(async () => {
  const [firestoreHost, firestorePort] = (
    process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088'
  ).split(':');
  const [storageHost, storagePort] = (
    process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199'
  ).split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-admin',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: firestoreHost,
      port: Number(firestorePort),
    },
    storage: {
      rules: readFileSync(new URL('../storage.rules', import.meta.url), 'utf8'),
      host: storageHost,
      port: Number(storagePort),
    },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    // The member belongs to the ronda every path is about, so membership opens nothing either.
    await setDoc(doc(db, 'rondas/r1'), {
      status: 'active',
      hosts: { anfitrion: 'demo-admin-host', cola: '' },
    });
    await setDoc(doc(db, `rondas/r1/members/${MEMBER}`), { state: 'active', joinedAt: NOW });
    for (const { path, fields } of ADMIN_PATHS) {
      await setDoc(doc(db, path), fields);
    }
    for (const path of STORED) {
      await uploadBytes(ref(context.storage(), path), new Uint8Array([1, 2, 3]));
    }
  });
});

after(() => env.cleanup());

const collectionOf = (path) => path.split('/').slice(0, -1).join('/');

const admin = () => env.authenticatedContext('demo-admin', { admin: true });

const NOT_ADMINS = [
  ['a signed-out visitor', () => env.unauthenticatedContext()],
  ['a member of the ronda', () => env.authenticatedContext(MEMBER)],
  ['admin: false', () => env.authenticatedContext(MEMBER, { admin: false })],
  ["admin: 'true'", () => env.authenticatedContext(MEMBER, { admin: 'true' })],
  ['admin: 1', () => env.authenticatedContext(MEMBER, { admin: 1 })],
  ["admin: 'yes'", () => env.authenticatedContext(MEMBER, { admin: 'yes' })],
  ["role: 'admin'", () => env.authenticatedContext(MEMBER, { role: 'admin' })],
];

describe('every admin path', () => {
  for (const { path, getOnly } of ADMIN_PATHS) {
    test(`the admin reads ${path}`, async () => {
      const db = admin().firestore();
      await assertSucceeds(getDoc(doc(db, path)));
      if (!getOnly) await assertSucceeds(getDocs(collection(db, collectionOf(path))));
    });

    for (const [who, context] of NOT_ADMINS) {
      test(`${who} reads neither ${path} nor its list`, async () => {
        const db = context().firestore();
        await assertFails(getDoc(doc(db, path)));
        await assertFails(getDocs(collection(db, collectionOf(path))));
      });
    }

    test(`no client writes ${path}, the admin included`, async () => {
      for (const context of [admin, ...NOT_ADMINS.map(([, c]) => c)]) {
        await assertFails(setDoc(doc(context().firestore(), path), { written: true }));
      }
    });
  }
});

describe('Storage', () => {
  for (const path of STORED) {
    test(`the admin claim does not read ${path}`, async () => {
      await assertFails(getBytes(ref(admin().storage(), path)));
    });

    test(`the admin claim does not write ${path}`, async () => {
      await assertFails(uploadBytes(ref(admin().storage(), path), new Uint8Array([4])));
    });
  }
});
