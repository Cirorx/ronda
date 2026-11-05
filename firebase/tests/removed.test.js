// A member who left or was removed under firestore.rules: removals.py and seguimos.py keep the
// member document with `state: left` (the history stays), so membership must read that state.
// The person keeps nothing: not the ronda, its members, who's coming, the acta, the después,
// nor (if they were a host) the weekly roll or the ronda's flyers. Active members are unchanged.
//
//   cd firebase/tests && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

const NOW = new Date('2026-11-06T13:00:00Z');
const WEEK = '2026-W45';
const ACTIVE = 'demo-removed-1';
const LEFT = 'demo-removed-2';
const HOST = 'demo-removed-3';
const LEFT_HOST = 'demo-removed-4';
const ASKED_LEFT = 'demo-removed-5';

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-removed',
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
    const documents = {
      'rondas/r1': {
        status: 'active',
        slot: { day: 'thu', time: 'afternoon', hour: '16:00' },
        hosts: { anfitrion: LEFT_HOST, cola: HOST },
      },
      [`rondas/r1/views/${WEEK}`]: { going: 3 },
      'acta/r1/entries/e1': { at: NOW, text: 'Se mandó la tarjeta de la semana.' },
      [`rondas/r1/despues/${WEEK}`]: {
        week: WEEK,
        kind: 'home',
        address: 'Av. Central 1234',
        status: 'set',
        setBy: HOST,
        homeOf: HOST,
      },
      [`rondas/r1/rolls/${WEEK}`]: { week: WEEK, people: [], askedUid: ASKED_LEFT },
      'flyers/f1': { kind: 'mate', rondaId: 'r1', createdBy: HOST },
    };
    for (const uid of [ACTIVE, HOST]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
    }
    for (const uid of [LEFT, LEFT_HOST, ASKED_LEFT]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'left', leftAt: NOW };
    }
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();

describe('a member who left', () => {
  test('reads nothing of the ronda any more', async () => {
    const db = as(LEFT);
    await assertFails(getDoc(doc(db, 'rondas/r1')));
    await assertFails(getDocs(collection(db, 'rondas/r1/members')));
    await assertFails(getDoc(doc(db, `rondas/r1/members/${ACTIVE}`)));
    await assertFails(getDoc(doc(db, `rondas/r1/views/${WEEK}`)));
    await assertFails(getDocs(collection(db, 'acta/r1/entries')));
    await assertFails(getDoc(doc(db, `rondas/r1/despues/${WEEK}`)));
  });

  test('loses the roll they were asked to take, once they left', async () => {
    await assertFails(getDoc(doc(as(ASKED_LEFT), `rondas/r1/rolls/${WEEK}`)));
  });
});

describe('a host who left', () => {
  test('loses the roll and the ronda flyers, though still listed in hosts', async () => {
    const db = as(LEFT_HOST);
    await assertFails(getDoc(doc(db, `rondas/r1/rolls/${WEEK}`)));
    await assertFails(getDoc(doc(db, 'flyers/f1')));
    await assertFails(getDoc(doc(db, 'rondas/r1')));
  });
});

describe('active members and hosts', () => {
  test('still read the ronda, who is coming, the acta and the después', async () => {
    const db = as(ACTIVE);
    await assertSucceeds(getDoc(doc(db, 'rondas/r1')));
    await assertSucceeds(getDocs(collection(db, 'rondas/r1/members')));
    await assertSucceeds(getDoc(doc(db, `rondas/r1/views/${WEEK}`)));
    await assertSucceeds(getDocs(collection(db, 'acta/r1/entries')));
    await assertSucceeds(getDoc(doc(db, `rondas/r1/despues/${WEEK}`)));
  });

  test('a current host still gets the roll and the flyer', async () => {
    const db = as(HOST);
    await assertSucceeds(getDoc(doc(db, `rondas/r1/rolls/${WEEK}`)));
    await assertSucceeds(getDoc(doc(db, 'flyers/f1')));
  });
});
