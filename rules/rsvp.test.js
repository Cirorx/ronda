// The weekly RSVP under firestore.rules: members read the derived "who's coming" view of their
// own ronda and their own answer, and nobody reads the raw rsvp map (#45).
//
//   cd rules && npm install && npm test
//
// The documents are written the way the answer_rsvp callable and the RSVP job write them
// (functions/rsvp.py), with the rules off, as the admin SDK skips them.
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

const NOW = new Date('2026-10-29T22:00:00Z');
const WEEK = '2026-W44';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-rsvp',
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
      'rondas/r1': { seatId: 'el-pinar-sur_mate_sat-afternoon', status: 'forming', size: 3 },
      'rondas/r1/members/demo-001': { brings: ['pan'], state: 'active', joinedAt: NOW },
      'rondas/r1/members/demo-002': { brings: ['termo'], state: 'active', joinedAt: NOW },
      'rondas/r2': { seatId: 'lagomar-sur_truco_tue-evening', status: 'forming', size: 1 },
      'rondas/r2/members/demo-009': { brings: [], state: 'active', joinedAt: NOW },
      [`rondas/r1/weeks/${WEEK}`]: {
        date: '2026-10-31',
        rsvp: { 'demo-001': 'yes', 'demo-002': 'no' },
        rsvpSentAt: NOW,
      },
      'rondas/r1/views/week': {
        week: WEEK,
        date: '2026-10-31',
        going: [{ uid: 'demo-001', firstName: 'Marta', brings: ['pan'] }],
        noCount: 1,
        unansweredCount: 0,
        updatedAt: NOW,
      },
      'rondas/r1/answers/demo-001': { week: WEEK, answer: 'yes', at: NOW },
      'rondas/r1/answers/demo-002': { week: WEEK, answer: 'no', at: NOW },
      'users/demo-001/rondas/r1': { joinedAt: NOW },
      'users/demo-009/rondas/r2': { joinedAt: NOW },
    };
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const member = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe("who's coming", () => {
  test('a member reads their ronda\'s view of the week', async () => {
    await assertSucceeds(getDoc(doc(member('demo-002'), 'rondas/r1/views/week')));
  });

  test('a member of another ronda, a visitor or the admin cannot', async () => {
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1/views/week')));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'rondas/r1/views/week')));
    await assertFails(getDoc(doc(admin(), 'rondas/r1/views/week')));
  });

  test('nobody writes the view from a client', async () => {
    const view = { week: WEEK, going: [], noCount: 0, unansweredCount: 2 };
    await assertFails(setDoc(doc(member('demo-001'), 'rondas/r1/views/week'), view));
    await assertFails(updateDoc(doc(member('demo-001'), 'rondas/r1/views/week'), { noCount: 0 }));
    await assertFails(deleteDoc(doc(member('demo-001'), 'rondas/r1/views/week')));
    await assertFails(setDoc(doc(admin(), 'rondas/r1/views/week'), view));
  });
});

describe('the raw rsvp map', () => {
  test('no member reads the week document that holds it, not even their own ronda\'s', async () => {
    await assertFails(getDoc(doc(member('demo-001'), `rondas/r1/weeks/${WEEK}`)));
    await assertFails(getDocs(collection(member('demo-001'), 'rondas/r1/weeks')));
  });

  test('nor the admin from a client', async () => {
    await assertFails(getDoc(doc(admin(), `rondas/r1/weeks/${WEEK}`)));
  });

  test('nobody writes an answer into it from a client', async () => {
    const ref = doc(member('demo-002'), `rondas/r1/weeks/${WEEK}`);
    await assertFails(updateDoc(ref, { 'rsvp.demo-002': 'yes' }));
    await assertFails(setDoc(ref, { rsvp: { 'demo-002': 'yes' } }, { merge: true }));
    await assertFails(setDoc(doc(member('demo-002'), 'rondas/r1/weeks/2026-W45'), { rsvp: {} }));
  });
});

describe('a member\'s own answer', () => {
  test('the member reads it', async () => {
    await assertSucceeds(getDoc(doc(member('demo-002'), 'rondas/r1/answers/demo-002')));
  });

  test('another member of the same ronda cannot, so a "no" stays private', async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'rondas/r1/answers/demo-002')));
    await assertFails(getDocs(collection(member('demo-001'), 'rondas/r1/answers')));
  });

  test('someone who is not in the ronda cannot read an answer under their own uid', async () => {
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1/answers/demo-009')));
  });

  test('nobody writes it from a client', async () => {
    const ref = doc(member('demo-002'), 'rondas/r1/answers/demo-002');
    await assertFails(setDoc(ref, { week: WEEK, answer: 'yes', at: NOW }));
    await assertFails(deleteDoc(ref));
  });
});

describe("the member's rondas", () => {
  test('a member lists their own', async () => {
    await assertSucceeds(getDocs(collection(member('demo-001'), 'users/demo-001/rondas')));
    await assertSucceeds(getDoc(doc(member('demo-001'), 'users/demo-001/rondas/r1')));
  });

  test("nobody lists someone else's", async () => {
    await assertFails(getDocs(collection(member('demo-009'), 'users/demo-001/rondas')));
    await assertFails(getDocs(collection(admin(), 'users/demo-001/rondas')));
  });

  test('nobody writes themselves into a ronda through it', async () => {
    await assertFails(setDoc(doc(member('demo-009'), 'users/demo-009/rondas/r1'), { joinedAt: NOW }));
    await assertFails(deleteDoc(doc(member('demo-001'), 'users/demo-001/rondas/r1')));
  });
});
