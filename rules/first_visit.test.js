// Así va a ser under firestore.rules (#70): one welcome per newcomer. The newcomer reads only
// their own; the ronda's anfitrión and cola read and list the ronda's, since they choose who
// waits; the member a host picked reads the one they were picked for, found by a query on
// `waiterUid`. Nobody else reads one, and no client writes any: functions/first_visit.py does,
// with the admin SDK.
//
//   cd rules && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel.
import { after, before, beforeEach, describe, test } from 'node:test';
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
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const NOW = new Date('2026-11-03T13:00:00Z');
const WEEK = '2026-W45';
const ANFITRION = 'demo-first-1';
const COLA = 'demo-first-2';
const WAITER = 'demo-first-3';
const MEMBER = 'demo-first-4';
const NICO = 'demo-first-5';
const LUCIA = 'demo-first-6';
const OTHER = 'demo-first-9';
const NICOS = `rondas/r1/welcomes/${NICO}`;
const LUCIAS = `rondas/r1/welcomes/${LUCIA}`;

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-first-visit',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host,
      port: Number(port),
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const welcome = {
      week: WEEK,
      date: '2026-11-05',
      hour: '16:00',
      choices: [],
      declined: [],
    };
    const documents = {
      'rondas/r1': {
        status: 'active',
        slot: { day: 'thu', time: 'afternoon', hour: '16:00' },
        hosts: { anfitrion: ANFITRION, cola: COLA },
      },
      'rondas/r2': {
        status: 'active',
        slot: { day: 'thu', time: 'afternoon' },
        hosts: { anfitrion: OTHER },
      },
      [NICOS]: {
        ...welcome,
        newcomerName: 'Nico',
        status: 'set',
        waiterUid: WAITER,
        waiterName: 'Jorge',
        sign: 'tiene el termo verde',
        setBy: ANFITRION,
        setByName: 'Mirta',
      },
      [LUCIAS]: { ...welcome, newcomerName: 'Lucía', status: 'open' },
      'rondas/r2/members/demo-first-9': { brings: [], state: 'active', joinedAt: NOW },
      [`rondas/r2/welcomes/${NICO}`]: { ...welcome, newcomerName: 'Nico', status: 'open' },
    };
    for (const uid of [ANFITRION, COLA, WAITER, MEMBER, NICO, LUCIA]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
    }
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();

describe('a newcomer', () => {
  test('reads their own welcome, waiter and sign included', async () => {
    const snapshot = await assertSucceeds(getDoc(doc(as(NICO), NICOS)));
    if (snapshot.data().waiterName !== 'Jorge') throw new Error('no waiter');
  });

  test("reads no other newcomer's and lists none", async () => {
    await assertFails(getDoc(doc(as(NICO), LUCIAS)));
    await assertFails(getDoc(doc(as(LUCIA), NICOS)));
    await assertFails(getDocs(collection(as(NICO), 'rondas/r1/welcomes')));
  });

  test("reads no welcome of a ronda they aren't in, their own uid's included", async () => {
    await assertFails(getDoc(doc(as(NICO), `rondas/r2/welcomes/${NICO}`)));
  });
});

describe("the ronda's hosts", () => {
  test('the anfitrión and the cola read and list every welcome of their ronda', async () => {
    for (const host of [ANFITRION, COLA]) {
      await assertSucceeds(getDoc(doc(as(host), LUCIAS)));
      const all = await assertSucceeds(getDocs(collection(as(host), 'rondas/r1/welcomes')));
      if (all.size !== 2) throw new Error(`listed ${all.size}`);
    }
  });

  test("read no other ronda's", async () => {
    await assertFails(getDocs(collection(as(ANFITRION), 'rondas/r2/welcomes')));
  });
});

describe('the member a host picked', () => {
  test('reads the welcome they were picked for, and finds it by query', async () => {
    await assertSucceeds(getDoc(doc(as(WAITER), NICOS)));
    const mine = query(collection(as(WAITER), 'rondas/r1/welcomes'), where('waiterUid', '==', WAITER));
    const found = await assertSucceeds(getDocs(mine));
    if (found.size !== 1) throw new Error(`found ${found.size}`);
  });

  test('a member nobody picked asks the same question and finds nothing', async () => {
    const mine = query(collection(as(MEMBER), 'rondas/r1/welcomes'), where('waiterUid', '==', MEMBER));
    const found = await assertSucceeds(getDocs(mine));
    if (found.size !== 0) throw new Error(`found ${found.size}`);
  });

  test('reads no other welcome and lists none unfiltered', async () => {
    await assertFails(getDoc(doc(as(WAITER), LUCIAS)));
    await assertFails(getDocs(collection(as(WAITER), 'rondas/r1/welcomes')));
  });
});

describe('everyone else', () => {
  test('another member, a stranger, the admin and a signed-out phone read nothing', async () => {
    for (const reader of [as(MEMBER), as(OTHER), admin(), signedOut()]) {
      await assertFails(getDoc(doc(reader, NICOS)));
    }
    const asked = query(collection(as(MEMBER), 'rondas/r1/welcomes'), where('waiterUid', '==', WAITER));
    await assertFails(getDocs(asked));
  });

  test('nobody writes one from a client: not a host, the waiter, the newcomer or the admin', async () => {
    await assertFails(updateDoc(doc(as(ANFITRION), LUCIAS), { waiterUid: COLA }));
    await assertFails(updateDoc(doc(as(WAITER), NICOS), { status: 'open' }));
    await assertFails(updateDoc(doc(as(NICO), NICOS), { sign: 'otra cosa' }));
    await assertFails(setDoc(doc(as(ANFITRION), `rondas/r1/welcomes/${MEMBER}`), { status: 'open' }));
    await assertFails(deleteDoc(doc(admin(), NICOS)));
  });
});
