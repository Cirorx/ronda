// ¿Dónde queda? (#58) under firestore.rules and storage.rules: the week's photo is read by the
// ronda's members only; each member reads only their own card; who was asked, the
// photographer's pin and every guess stay closed to every client; and nobody but the owner
// uploads or deletes a photo before it is checked.
//
//   cd rules && npm install
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 \
//     FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 npm test
//
// It runs on its own project id, since node runs test files in parallel. Every person is
// invented.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';
import { deleteObject, getBytes, ref, uploadBytes } from 'firebase/storage';

const PHOTOGRAPHER = 'demo-dq-photo';
const MEMBER = 'demo-dq-member';
const LEFT = 'demo-dq-left';
const OTHER = 'demo-dq-other';
const WEEK = '2026-W45';
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const photo = { contentType: 'image/jpeg' };
const PUBLISHED = `donde_queda/r1/${WEEK}.jpg`;

let env;

before(async () => {
  const [firestoreHost, firestorePort] = (
    process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088'
  ).split(':');
  const [storageHost, storagePort] = (
    process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199'
  ).split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-donde-queda',
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
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'rondas/r1'), { pretext: 'mate', barrio: 'el-pinar-sur' });
    await setDoc(doc(db, `rondas/r1/members/${PHOTOGRAPHER}`), { state: 'active' });
    await setDoc(doc(db, `rondas/r1/members/${MEMBER}`), { state: 'active' });
    await setDoc(doc(db, `rondas/r1/members/${LEFT}`), { state: 'left' });
    await setDoc(doc(db, 'rondas/r2'), { pretext: 'truco' });
    await setDoc(doc(db, `rondas/r2/members/${OTHER}`), { state: 'active' });
    await setDoc(doc(db, 'rondas/r1/views/donde_queda'), {
      current: { week: WEEK, status: 'open', photoPath: PUBLISHED, hint: '' },
      reveal: null,
    });
    await setDoc(doc(db, `rondas/r1/donde_queda/${WEEK}`), {
      status: 'open',
      asked: PHOTOGRAPHER,
      photographer: PHOTOGRAPHER,
      pin: { lat: -34.8, lng: -55.885 },
      guesses: { [MEMBER]: { lat: -34.8, lng: -55.885 } },
    });
    await setDoc(doc(db, `rondas/r1/donde_queda_players/${MEMBER}`), {
      week: WEEK,
      asked: false,
      posted: false,
      guessed: true,
    });
    await setDoc(doc(db, `rondas/r1/donde_queda_players/${PHOTOGRAPHER}`), {
      week: WEEK,
      asked: true,
      posted: true,
      guessed: false,
    });
    await setDoc(doc(db, 'rondas/r1/private/donde_queda'), { lastStarter: PHOTOGRAPHER });
    await uploadBytes(ref(context.storage(), PUBLISHED), JPEG, photo);
  });
});

after(() => env.cleanup());

const firestoreOf = (uid) => env.authenticatedContext(uid).firestore();
const storageOf = (uid) => env.authenticatedContext(uid).storage();

describe("the week's published photo", () => {
  test("is read by the ronda's members", async () => {
    await assertSucceeds(getBytes(ref(storageOf(MEMBER), PUBLISHED)));
    await assertSucceeds(getBytes(ref(storageOf(PHOTOGRAPHER), PUBLISHED)));
  });

  test('is not read by a member who left, another ronda, or signed out', async () => {
    await assertFails(getBytes(ref(storageOf(LEFT), PUBLISHED)));
    await assertFails(getBytes(ref(storageOf(OTHER), PUBLISHED)));
    await assertFails(getBytes(ref(env.unauthenticatedContext().storage(), PUBLISHED)));
  });

  test('is written and deleted by no client, not even the photographer', async () => {
    await assertFails(uploadBytes(ref(storageOf(PHOTOGRAPHER), PUBLISHED), JPEG, photo));
    await assertFails(
      uploadBytes(ref(storageOf(PHOTOGRAPHER), `donde_queda/r1/2026-W46.jpg`), JPEG, photo),
    );
    await assertFails(deleteObject(ref(storageOf(PHOTOGRAPHER), PUBLISHED)));
  });
});

describe('a photo upload before the check', () => {
  const path = (uid, name) => `donde_queda_photos/${uid}/${name}`;
  const upload = (uid, at, data = JPEG, metadata = photo) =>
    uploadBytes(ref(storageOf(uid), at), data, metadata);

  test('is written by its owner as a JPEG of at most 3 MB', async () => {
    await assertSucceeds(upload(PHOTOGRAPHER, path(PHOTOGRAPHER, 'p1.jpg')));
    await assertFails(
      upload(PHOTOGRAPHER, path(PHOTOGRAPHER, 'p2.jpg'), JPEG, { contentType: 'image/png' }),
    );
    await assertFails(
      upload(PHOTOGRAPHER, path(PHOTOGRAPHER, 'p3.jpg'), new Uint8Array(3 * 1024 * 1024 + 1)),
    );
    await assertFails(upload(PHOTOGRAPHER, path(PHOTOGRAPHER, 'p 4.jpg')));
  });

  test("is not written into someone else's folder", async () => {
    await assertFails(upload(MEMBER, path(PHOTOGRAPHER, 'p5.jpg')));
  });

  test('is never read back, and deleted by its owner only', async () => {
    await assertSucceeds(upload(PHOTOGRAPHER, path(PHOTOGRAPHER, 'p6.jpg')));
    await assertFails(getBytes(ref(storageOf(PHOTOGRAPHER), path(PHOTOGRAPHER, 'p6.jpg'))));
    await assertFails(deleteObject(ref(storageOf(MEMBER), path(PHOTOGRAPHER, 'p6.jpg'))));
    await assertSucceeds(deleteObject(ref(storageOf(PHOTOGRAPHER), path(PHOTOGRAPHER, 'p6.jpg'))));
  });
});

describe('what members read of the game', () => {
  test("the view is read by the ronda's members only", async () => {
    await assertSucceeds(getDoc(doc(firestoreOf(MEMBER), 'rondas/r1/views/donde_queda')));
    await assertFails(getDoc(doc(firestoreOf(OTHER), 'rondas/r1/views/donde_queda')));
  });

  test('each member reads only their own card', async () => {
    await assertSucceeds(
      getDoc(doc(firestoreOf(MEMBER), `rondas/r1/donde_queda_players/${MEMBER}`)),
    );
    await assertFails(
      getDoc(doc(firestoreOf(MEMBER), `rondas/r1/donde_queda_players/${PHOTOGRAPHER}`)),
    );
    await assertFails(getDocs(collection(firestoreOf(MEMBER), 'rondas/r1/donde_queda_players')));
    await assertFails(
      getDoc(doc(firestoreOf(OTHER), `rondas/r1/donde_queda_players/${OTHER}`)),
    );
  });

  test('who was asked, the pin and the guesses stay closed, even to the photographer', async () => {
    for (const uid of [MEMBER, PHOTOGRAPHER]) {
      await assertFails(getDoc(doc(firestoreOf(uid), `rondas/r1/donde_queda/${WEEK}`)));
      await assertFails(getDocs(collection(firestoreOf(uid), 'rondas/r1/donde_queda')));
      await assertFails(getDoc(doc(firestoreOf(uid), 'rondas/r1/private/donde_queda')));
    }
  });

  test('no client writes any of it', async () => {
    const db = firestoreOf(MEMBER);
    await assertFails(
      setDoc(doc(db, `rondas/r1/donde_queda_players/${MEMBER}`), { guessed: false }),
    );
    await assertFails(setDoc(doc(db, `rondas/r1/donde_queda/${WEEK}`), { guesses: {} }));
    await assertFails(setDoc(doc(db, 'rondas/r1/views/donde_queda'), { reveal: null }));
  });
});
