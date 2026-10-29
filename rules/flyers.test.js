// "Un mate de más" under firestore.rules and storage.rules: only the owner
// uploads their blurred photo and reads back the flyer drawn from it; a
// `flyers/{id}` document of kind `mate` is read by the host who made it and by
// that ronda's hosts, and written by no client.
//
//   cd rules && npm install
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 \
//     FIREBASE_STORAGE_EMULATOR_HOST=127.0.0.1:9199 npm test
//
// It runs on its own project id, since node runs test files in parallel.
// Loading storage.rules replaces the Storage emulator's rules for every
// project, so a shared emulator ends up with this checkout's storage.rules.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';
import {
  deleteObject,
  getBytes,
  ref,
  uploadBytes,
  uploadString,
} from 'firebase/storage';

const HOST = 'demo-flyer-host';
const COLA = 'demo-flyer-cola';
const MEMBER = 'demo-flyer-member';
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const photo = { contentType: 'image/jpeg' };

let env;

before(async () => {
  const [firestoreHost, firestorePort] = (
    process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088'
  ).split(':');
  const [storageHost, storagePort] = (
    process.env.FIREBASE_STORAGE_EMULATOR_HOST ?? '127.0.0.1:9199'
  ).split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-flyer',
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
    await setDoc(doc(db, 'rondas/r1'), {
      pretext: 'mate',
      hosts: { anfitrion: HOST, cola: COLA },
    });
    await setDoc(doc(db, 'rondas/r1/members/' + MEMBER), { state: 'active' });
    await setDoc(doc(db, 'rondas/r2'), { pretext: 'truco' });
    await setDoc(doc(db, 'flyers/mate-1'), {
      kind: 'mate',
      rondaId: 'r1',
      createdBy: HOST,
      imagePath: `flyers/${HOST}/mate-1.jpg`,
    });
    await setDoc(doc(db, 'flyers/mate-2'), {
      kind: 'mate',
      rondaId: 'r2',
      createdBy: MEMBER,
      imagePath: `flyers/${MEMBER}/mate-2.jpg`,
    });
    await setDoc(doc(db, 'flyers/tear-1'), {
      kind: 'tearOff',
      createdBy: HOST,
      rondaId: 'r1',
    });
    const storage = context.storage();
    await uploadBytes(ref(storage, `flyers/${HOST}/mate-1.jpg`), JPEG, photo);
  });
});

after(() => env.cleanup());

const firestoreOf = (uid) => env.authenticatedContext(uid).firestore();
const storageOf = (uid) => env.authenticatedContext(uid).storage();

describe('a mate flyer document', () => {
  test('is read by the host who made it', async () => {
    await assertSucceeds(getDoc(doc(firestoreOf(HOST), 'flyers/mate-1')));
    await assertSucceeds(getDoc(doc(firestoreOf(MEMBER), 'flyers/mate-2')));
  });

  test("is read by the ronda's other host", async () => {
    await assertSucceeds(getDoc(doc(firestoreOf(COLA), 'flyers/mate-1')));
  });

  test('is not read by a member who is not a host, or signed out', async () => {
    await assertFails(getDoc(doc(firestoreOf(MEMBER), 'flyers/mate-1')));
    await assertFails(getDoc(doc(firestoreOf(COLA), 'flyers/mate-2')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'flyers/mate-1')));
  });

  test('is never listed', async () => {
    await assertFails(getDocs(collection(firestoreOf(HOST), 'flyers')));
  });

  test('is written by no client, not even its host', async () => {
    const db = firestoreOf(HOST);
    await assertFails(
      setDoc(doc(db, 'flyers/mine'), { kind: 'mate', rondaId: 'r1', createdBy: HOST }),
    );
    await assertFails(updateDoc(doc(db, 'flyers/mate-1'), { rondaId: 'r2' }));
  });

  test('opens nothing of a tear-off flyer', async () => {
    await assertFails(getDoc(doc(firestoreOf(HOST), 'flyers/tear-1')));
  });
});

describe('a flyer photo upload', () => {
  const upload = (uid, path, data = JPEG, metadata = photo) =>
    uploadBytes(ref(storageOf(uid), path), data, metadata);

  test('is written by its owner as a JPEG', async () => {
    await assertSucceeds(upload(HOST, `flyer_photos/${HOST}/photo-1.jpg`));
  });

  test("is not written into someone else's folder, or signed out", async () => {
    await assertFails(upload(MEMBER, `flyer_photos/${HOST}/photo-2.jpg`));
    await assertFails(
      uploadBytes(
        ref(env.unauthenticatedContext().storage(), `flyer_photos/${HOST}/photo-3.jpg`),
        JPEG,
        photo,
      ),
    );
  });

  test('is a JPEG of at most 3 MB with a plain name', async () => {
    await assertFails(
      upload(HOST, `flyer_photos/${HOST}/photo-4.png`, JPEG, { contentType: 'image/png' }),
    );
    await assertFails(
      upload(HOST, `flyer_photos/${HOST}/photo-5.jpg`, JPEG, { contentType: 'image/png' }),
    );
    await assertFails(upload(HOST, `flyer_photos/${HOST}/photo 6.jpg`));
    await assertFails(
      upload(HOST, `flyer_photos/${HOST}/photo-7.jpg`, new Uint8Array(3 * 1024 * 1024 + 1)),
    );
  });

  test('is never read back, even by its owner', async () => {
    await assertSucceeds(upload(HOST, `flyer_photos/${HOST}/photo-8.jpg`));
    await assertFails(getBytes(ref(storageOf(HOST), `flyer_photos/${HOST}/photo-8.jpg`)));
  });

  test('is deleted by its owner only', async () => {
    await assertSucceeds(upload(HOST, `flyer_photos/${HOST}/photo-9.jpg`));
    await assertFails(deleteObject(ref(storageOf(MEMBER), `flyer_photos/${HOST}/photo-9.jpg`)));
    await assertSucceeds(deleteObject(ref(storageOf(HOST), `flyer_photos/${HOST}/photo-9.jpg`)));
  });
});

describe('a drawn flyer image', () => {
  test('is read by the host who made it', async () => {
    await assertSucceeds(getBytes(ref(storageOf(HOST), `flyers/${HOST}/mate-1.jpg`)));
  });

  test('is not read by anyone else', async () => {
    await assertFails(getBytes(ref(storageOf(COLA), `flyers/${HOST}/mate-1.jpg`)));
    await assertFails(
      getBytes(ref(env.unauthenticatedContext().storage(), `flyers/${HOST}/mate-1.jpg`)),
    );
  });

  test('is written by no client', async () => {
    await assertFails(uploadString(ref(storageOf(HOST), `flyers/${HOST}/fake.jpg`), 'x'));
  });
});
