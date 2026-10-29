// FCM tokens under firestore.rules: a member saves and removes only their own
// phones' tokens, as exactly {platform, updatedAt}, and nobody reads them back
// from a client.
//
//   cd rules && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel; every
// test makes its own documents, so nothing needs clearing.
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
  serverTimestamp,
  setDoc,
} from 'firebase/firestore';

// An invented token: real ones address a phone and never appear in the repo.
const TOKEN = 'fake-fcm-token:APA91b-invented';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-tokens',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8088,
    },
  });
});

after(() => env.cleanup());

const member = (uid) => env.authenticatedContext(uid).firestore();
const token = (db, uid, id = TOKEN) => doc(db, `users/${uid}/tokens/${id}`);
const saved = (platform = 'android') => ({ platform, updatedAt: serverTimestamp() });

describe('the owner', () => {
  test('saves a token from each platform', async () => {
    for (const platform of ['android', 'ios', 'web']) {
      await assertSucceeds(
        setDoc(token(member('demo-tok-1'), 'demo-tok-1', `${TOKEN}-${platform}`), saved(platform)),
      );
    }
  });

  test('saves the same token again, which refreshes it', async () => {
    const db = member('demo-tok-2');
    await assertSucceeds(setDoc(token(db, 'demo-tok-2'), saved()));
    await assertSucceeds(setDoc(token(db, 'demo-tok-2'), saved()));
  });

  test('removes a token', async () => {
    const db = member('demo-tok-3');
    await assertSucceeds(setDoc(token(db, 'demo-tok-3'), saved()));
    await assertSucceeds(deleteDoc(token(db, 'demo-tok-3')));
  });

  test('cannot read a token back, or list them', async () => {
    const db = member('demo-tok-4');
    await assertSucceeds(setDoc(token(db, 'demo-tok-4'), saved()));
    await assertFails(getDoc(token(db, 'demo-tok-4')));
    await assertFails(getDocs(collection(db, 'users/demo-tok-4/tokens')));
  });
});

describe('a token document', () => {
  const db = () => member('demo-tok-5');

  test('carries nothing but the platform and the time', async () => {
    await assertFails(setDoc(token(db(), 'demo-tok-5'), { ...saved(), uid: 'demo-tok-5' }));
    await assertFails(setDoc(token(db(), 'demo-tok-5'), { ...saved(), token: TOKEN }));
  });

  test('needs both fields', async () => {
    await assertFails(setDoc(token(db(), 'demo-tok-5'), { platform: 'android' }));
    await assertFails(setDoc(token(db(), 'demo-tok-5'), { updatedAt: serverTimestamp() }));
  });

  test('names one of the three platforms', async () => {
    await assertFails(setDoc(token(db(), 'demo-tok-5'), saved('windows')));
    await assertFails(setDoc(token(db(), 'demo-tok-5'), saved('')));
  });

  test("takes the server's time, not the phone's", async () => {
    await assertFails(
      setDoc(token(db(), 'demo-tok-5'), { platform: 'android', updatedAt: new Date() }),
    );
  });
});

describe('anyone else', () => {
  test('cannot save, remove or read a member’s token', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(token(context.firestore(), 'demo-tok-6'), { platform: 'android', updatedAt: new Date() }),
    );
    const other = member('demo-tok-7');
    await assertFails(setDoc(token(other, 'demo-tok-6'), saved()));
    await assertFails(deleteDoc(token(other, 'demo-tok-6')));
    await assertFails(getDoc(token(other, 'demo-tok-6')));
    await assertFails(getDocs(collection(other, 'users/demo-tok-6/tokens')));
  });

  test('signed out, cannot do any of it', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(setDoc(token(db, 'demo-tok-6'), saved()));
    await assertFails(deleteDoc(token(db, 'demo-tok-6')));
    await assertFails(getDoc(token(db, 'demo-tok-6')));
  });
});
