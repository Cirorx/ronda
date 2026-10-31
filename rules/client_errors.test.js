// The web app's error log under firestore.rules: the report_client_error callable writes
// client_errors with the admin SDK, the admin reads it on /admin/errores, and no client
// writes it. The callable's per-caller quota, client_error_quota, is closed to everyone.
//
//   cd rules && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

// An invented report, in the shape functions/client_errors.py writes.
const REPORT = {
  platform: 'web',
  appVersion: '1.0.0',
  build: '1',
  flavor: 'production',
  screen: '/onboarding',
  step: 'voiceUpload',
  code: 'firebase_storage/unauthorized',
  message: 'Upload failed',
  stack: '',
  fatal: false,
  at: new Date('2026-10-30T21:00:00Z'),
  expireAt: new Date('2026-11-29T21:00:00Z'),
};

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-errors',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8088,
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'client_errors/demo-error'), REPORT);
    await setDoc(doc(db, 'client_error_quota/ipdemo_2026103021'), { count: 1 });
  });
});

after(() => env.cleanup());

const anyone = () => env.unauthenticatedContext().firestore();
const member = () => env.authenticatedContext('demo-err-1').firestore();
const admin = () =>
  env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe('the admin', () => {
  test('reads one report', async () => {
    await assertSucceeds(getDoc(doc(admin(), 'client_errors/demo-error')));
  });

  test('lists the newest reports', async () => {
    await assertSucceeds(
      getDocs(query(collection(admin(), 'client_errors'), orderBy('at', 'desc'), limit(50))),
    );
  });

  test('writes nothing', async () => {
    await assertFails(setDoc(doc(admin(), 'client_errors/new'), REPORT));
    await assertFails(updateDoc(doc(admin(), 'client_errors/demo-error'), { fatal: true }));
    await assertFails(deleteDoc(doc(admin(), 'client_errors/demo-error')));
  });

  test('cannot read the quota', async () => {
    await assertFails(getDoc(doc(admin(), 'client_error_quota/ipdemo_2026103021')));
  });
});

describe('a member or a signed-out visitor', () => {
  test('reads no report', async () => {
    for (const db of [anyone(), member()]) {
      await assertFails(getDoc(doc(db, 'client_errors/demo-error')));
      await assertFails(getDocs(collection(db, 'client_errors')));
    }
  });

  test('writes no report, not even their own', async () => {
    for (const db of [anyone(), member()]) {
      await assertFails(setDoc(doc(db, 'client_errors/new'), REPORT));
      await assertFails(updateDoc(doc(db, 'client_errors/demo-error'), { fatal: true }));
      await assertFails(deleteDoc(doc(db, 'client_errors/demo-error')));
    }
  });

  test('cannot read or move the quota', async () => {
    for (const db of [anyone(), member()]) {
      await assertFails(getDoc(doc(db, 'client_error_quota/ipdemo_2026103021')));
      await assertFails(setDoc(doc(db, 'client_error_quota/ipdemo_2026103021'), { count: 0 }));
    }
  });
});
