// The bench and the waiting list under firestore.rules (#48): each offer and each waiting card
// is read by its own person only, and nobody reads who is on a bench, the week's bench run or
// the lists themselves.
//
//   cd rules && npm install && npm test
//
// The documents are written the way functions/bench.py and functions/waitlists.py write them,
// with the rules off, as the admin SDK skips them.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc, updateDoc } from 'firebase/firestore';

const NOW = new Date('2026-11-04T13:00:00Z');
const OFFER = 'r1_2026-W45_01';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-bench',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8088,
    },
  });
});

after(() => env.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    const documents = {
      'rondas/r1': { pretext: 'mate', status: 'active' },
      'rondas/r1/members/demo-001': { brings: ['pan'], state: 'active', joinedAt: NOW },
      'rondas/r1/bench/2026-W45': {
        offers: [{ offerId: OFFER, uid: 'demo-201', firstName: 'Eva', status: 'pending' }],
        skipped: 0,
      },
      [`users/demo-201/offers/${OFFER}`]: {
        rondaId: 'r1',
        week: '2026-W45',
        date: '2026-11-05',
        status: 'pending',
        deadline: NOW,
      },
      'waitlists/el-pinar-sur_mate_sat-afternoon': {
        entries: [{ uid: 'demo-201', at: NOW }, { uid: 'demo-202', at: NOW }],
        choices: { 'demo-202': 'join' },
      },
      'waiting/demo-201': { seatId: 'el-pinar-sur_mate_sat-afternoon', count: 2, threshold: 6, status: 'open' },
    };
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const person = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();
const visitor = () => env.unauthenticatedContext().firestore();

describe('an offer of a freed seat', () => {
  test('its person reads it, alone or in their list', async () => {
    await assertSucceeds(getDoc(doc(person('demo-201'), `users/demo-201/offers/${OFFER}`)));
    await assertSucceeds(getDocs(collection(person('demo-201'), 'users/demo-201/offers')));
  });

  test('nobody else reads it: not a member of the ronda, not the admin, not a visitor', async () => {
    for (const db of [person('demo-001'), person('demo-202'), admin(), visitor()]) {
      await assertFails(getDoc(doc(db, `users/demo-201/offers/${OFFER}`)));
      await assertFails(getDocs(collection(db, 'users/demo-201/offers')));
    }
  });

  test('no client writes it, not even its person: the callable answers it', async () => {
    const db = person('demo-201');
    await assertFails(updateDoc(doc(db, `users/demo-201/offers/${OFFER}`), { status: 'taken' }));
    await assertFails(setDoc(doc(db, 'users/demo-201/offers/mine'), { status: 'taken' }));
    await assertFails(deleteDoc(doc(db, `users/demo-201/offers/${OFFER}`)));
  });
});

describe("the week's bench", () => {
  test('nobody reads who is on it or what it did, not even the admin', async () => {
    for (const db of [person('demo-001'), person('demo-201'), admin()]) {
      await assertFails(getDoc(doc(db, 'rondas/r1/bench/2026-W45')));
      await assertFails(getDocs(collection(db, 'rondas/r1/bench')));
    }
  });
});

describe('the waiting list', () => {
  test('each waiting person reads their own card only', async () => {
    await assertSucceeds(getDoc(doc(person('demo-201'), 'waiting/demo-201')));
    await assertFails(getDoc(doc(person('demo-202'), 'waiting/demo-201')));
    await assertFails(getDocs(collection(person('demo-201'), 'waiting')));
    await assertFails(getDoc(doc(visitor(), 'waiting/demo-201')));
  });

  test('nobody writes a card, and nobody reads the lists', async () => {
    await assertFails(updateDoc(doc(person('demo-201'), 'waiting/demo-201'), { count: 6 }));
    for (const db of [person('demo-201'), admin(), visitor()]) {
      await assertFails(getDoc(doc(db, 'waitlists/el-pinar-sur_mate_sat-afternoon')));
      await assertFails(getDocs(collection(db, 'waitlists')));
    }
  });
});
