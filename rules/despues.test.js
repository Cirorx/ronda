// The después and "¿Abrís vos?" under firestore.rules (#47): the después, which may be a
// member's home and its address, is read with `get` by that ronda's members once it is set, and
// by whoever set it and the person whose home it would be at any time; each member reads only
// their own "¿Abrís vos?"; the attendance roll opens to whoever took over opening that week.
// No client writes any of it: functions/despues.py and functions/handoff.py do, with the admin
// SDK.
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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const NOW = new Date('2026-11-04T13:00:00Z');
const WEEK = '2026-W45';
const ANFITRION = 'demo-loop-1';
const COLA = 'demo-loop-2';
const HOME_OWNER = 'demo-loop-3';
const MEMBER = 'demo-loop-4';
const OTHER = 'demo-loop-9';
const SET = `rondas/r1/despues/${WEEK}`;
const ASKING = `rondas/r2/despues/${WEEK}`;
const HANDOFF = `rondas/r1/handoffs/${WEEK}`;
const ROLL = `rondas/r1/rolls/${WEEK}`;

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-hosts2',
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
    const home = {
      week: WEEK,
      date: '2026-11-05',
      kind: 'home',
      what: 'bizcochos',
      address: 'Av. Central 1234',
      setBy: ANFITRION,
      setByName: 'Mirta',
    };
    const documents = {
      'rondas/r1': {
        status: 'active',
        slot: { day: 'thu', time: 'afternoon', hour: '16:00' },
        hosts: { anfitrion: ANFITRION, cola: COLA },
        opener: { week: WEEK, uid: MEMBER, firstName: 'Facu' },
      },
      'rondas/r2': { status: 'active', slot: { day: 'thu', time: 'afternoon' } },
      [SET]: { ...home, homeOf: ANFITRION, homeName: 'Mirta', status: 'set' },
      [ASKING]: { ...home, homeOf: HOME_OWNER, homeName: 'Ana', status: 'asking' },
      [HANDOFF]: { fromUid: ANFITRION, reason: 'no', step: 'cola', asked: [COLA] },
      [`rondas/r1/handoff_asks/${COLA}`]: { week: WEEK, fromName: 'Mirta', status: 'open' },
      [ROLL]: { week: WEEK, people: [], marks: {}, askedUid: MEMBER, askedRole: 'opener' },
    };
    for (const uid of [ANFITRION, COLA, HOME_OWNER, MEMBER]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
      documents[`rondas/r2/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
    }
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();
const signedOut = () => env.unauthenticatedContext().firestore();

describe('the después', () => {
  test("once it is set, the ronda's members read it, address and all", async () => {
    for (const uid of [ANFITRION, COLA, HOME_OWNER, MEMBER]) {
      const snapshot = await assertSucceeds(getDoc(doc(as(uid), SET)));
      assert(snapshot.data().address === 'Av. Central 1234');
    }
  });

  test('a member may look for one that is not set yet', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'rondas/r1/despues/2026-W46')));
  });

  test('nobody outside the ronda reads it: not a stranger, not signed out, not the admin', async () => {
    await assertFails(getDoc(doc(as(OTHER), SET)));
    await assertFails(getDoc(doc(signedOut(), SET)));
    await assertFails(getDoc(doc(admin(), SET)));
  });

  test("while it waits for a yes, only who set it and whose home it is read it", async () => {
    await assertSucceeds(getDoc(doc(as(ANFITRION), ASKING)));
    await assertSucceeds(getDoc(doc(as(HOME_OWNER), ASKING)));
    await assertFails(getDoc(doc(as(COLA), ASKING)));
    await assertFails(getDoc(doc(as(MEMBER), ASKING)));
  });

  test('nobody lists them, not even a member', async () => {
    await assertFails(getDocs(collection(as(MEMBER), 'rondas/r1/despues')));
  });

  test('nobody writes it from a client, its host and the admin included', async () => {
    await assertFails(updateDoc(doc(as(ANFITRION), SET), { address: 'Calle 2 345' }));
    await assertFails(setDoc(doc(as(ANFITRION), 'rondas/r1/despues/2026-W46'), { kind: 'none' }));
    await assertFails(updateDoc(doc(as(HOME_OWNER), ASKING), { status: 'set' }));
    await assertFails(deleteDoc(doc(admin(), SET)));
  });
});

describe('"¿Abrís vos?"', () => {
  test('the member asked reads their own question; nobody else does', async () => {
    const own = `rondas/r1/handoff_asks/${COLA}`;
    await assertSucceeds(getDoc(doc(as(COLA), own)));
    await assertSucceeds(getDoc(doc(as(MEMBER), `rondas/r1/handoff_asks/${MEMBER}`)));
    await assertFails(getDoc(doc(as(MEMBER), own)));
    await assertFails(getDoc(doc(as(ANFITRION), own)));
    await assertFails(getDocs(collection(as(COLA), 'rondas/r1/handoff_asks')));
  });

  test("who was asked and why the anfitrión can't stays closed, to the admin too", async () => {
    for (const reader of [as(ANFITRION), as(COLA), admin()]) {
      await assertFails(getDoc(doc(reader, HANDOFF)));
    }
  });

  test('nobody answers by writing it', async () => {
    await assertFails(
      updateDoc(doc(as(COLA), `rondas/r1/handoff_asks/${COLA}`), { status: 'taken' }),
    );
    await assertFails(updateDoc(doc(as(COLA), HANDOFF), { step: 'taken' }));
  });

  test('whoever took over opening gets the roll they were asked for, and no other', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), ROLL)));
    await assertFails(getDoc(doc(as(MEMBER), 'rondas/r1/rolls/2026-W46')));
    await assertFails(getDoc(doc(as(HOME_OWNER), ROLL)));
    await assertFails(updateDoc(doc(as(MEMBER), ROLL), { [`marks.${COLA}`]: true }));
  });
});

function assert(condition) {
  if (!condition) throw new Error('assertion failed');
}
