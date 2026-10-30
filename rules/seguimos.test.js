// ¿Seguimos? under firestore.rules: no client reads who said what (#46). Each member reads
// only their own question and its result, the admin only counts.
//
//   cd rules && npm install && npm test
//
// The documents are written the way the answer_seguimos callable and the jobs write them
// (functions/seguimos.py), with the rules off, as the admin SDK skips them.
import { after, before, beforeEach, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection,
  collectionGroup,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const NOW = new Date('2026-10-31T23:00:00Z');

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-seguimos',
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
      'rondas/r1': { pretext: 'mate', status: 'active', season: { start: '2026-11-03', end: '2026-11-24' } },
      'rondas/r1/members/demo-001': { brings: ['pan'], state: 'active', joinedAt: NOW },
      'rondas/r1/members/demo-002': { brings: [], state: 'left', joinedAt: NOW },
      'rondas/r2': { pretext: 'truco', status: 'forming' },
      'rondas/r2/members/demo-009': { brings: [], state: 'active', joinedAt: NOW },
      'rondas/r1/private/seguimos': {
        askedAt: NOW,
        asked: ['demo-001', 'demo-002'],
        answers: { 'demo-001': 'yes', 'demo-002': 'no' },
        choices: {},
        closedAt: NOW,
        outcome: 'season',
      },
      'rondas/r1/seguimos/demo-001': { status: 'closed', answer: 'yes', outcome: 'season' },
      'rondas/r1/seguimos/demo-002': { status: 'closed', answer: 'no', outcome: 'gracias', alternatives: [] },
      'seguimos_counts/r1': { line: 'Sábado a la tarde · mate en la rambla', status: 'season', asked: 2, yes: 1, no: 1, unanswered: 0 },
    };
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const member = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();
const visitor = () => env.unauthenticatedContext().firestore();

describe('who said what', () => {
  test('no member reads the private answers, not even of their own ronda', async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'rondas/r1/private/seguimos')));
    await assertFails(getDocs(collection(member('demo-001'), 'rondas/r1/private')));
  });

  test('nor the admin, another ronda\'s member or a visitor', async () => {
    await assertFails(getDoc(doc(admin(), 'rondas/r1/private/seguimos')));
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1/private/seguimos')));
    await assertFails(getDoc(doc(visitor(), 'rondas/r1/private/seguimos')));
    await assertFails(getDocs(collectionGroup(admin(), 'private')));
  });

  test('nobody writes an answer into it from a client', async () => {
    const ref = doc(member('demo-001'), 'rondas/r1/private/seguimos');
    await assertFails(updateDoc(ref, { 'answers.demo-001': 'no' }));
    await assertFails(setDoc(ref, { answers: { 'demo-001': 'no' } }, { merge: true }));
    await assertFails(deleteDoc(ref));
    await assertFails(setDoc(doc(admin(), 'rondas/r2/private/seguimos'), { answers: {} }));
  });
});

describe("a member's own question", () => {
  test('the member reads theirs, also after leaving at the close', async () => {
    await assertSucceeds(getDoc(doc(member('demo-001'), 'rondas/r1/seguimos/demo-001')));
    await assertSucceeds(getDoc(doc(member('demo-002'), 'rondas/r1/seguimos/demo-002')));
  });

  test("another member of the same ronda cannot read it or list them, so a no stays private", async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'rondas/r1/seguimos/demo-002')));
    await assertFails(getDocs(collection(member('demo-001'), 'rondas/r1/seguimos')));
    await assertFails(getDocs(collectionGroup(member('demo-001'), 'seguimos')));
  });

  test('nor the admin, a visitor, or someone outside the ronda under their own uid', async () => {
    await assertFails(getDoc(doc(admin(), 'rondas/r1/seguimos/demo-001')));
    await assertFails(getDoc(doc(visitor(), 'rondas/r1/seguimos/demo-001')));
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1/seguimos/demo-009')));
  });

  test('nobody writes it from a client, not even its owner', async () => {
    const ref = doc(member('demo-001'), 'rondas/r1/seguimos/demo-001');
    await assertFails(updateDoc(ref, { answer: 'no' }));
    await assertFails(setDoc(ref, { status: 'open' }));
    await assertFails(deleteDoc(ref));
  });
});

describe('the counts', () => {
  test('the admin reads them, one ronda or all', async () => {
    await assertSucceeds(getDoc(doc(admin(), 'seguimos_counts/r1')));
    await assertSucceeds(getDocs(collection(admin(), 'seguimos_counts')));
  });

  test('no member or visitor reads them, not even of their own ronda', async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'seguimos_counts/r1')));
    await assertFails(getDocs(collection(member('demo-001'), 'seguimos_counts')));
    await assertFails(getDoc(doc(visitor(), 'seguimos_counts/r1')));
  });

  test('nobody writes them from a client', async () => {
    await assertFails(setDoc(doc(admin(), 'seguimos_counts/r1'), { yes: 9 }));
    await assertFails(updateDoc(doc(member('demo-001'), 'seguimos_counts/r1'), { yes: 9 }));
  });
});

describe('the outcome', () => {
  test("members read only the season on their ronda, and nobody else's ronda", async () => {
    const ronda = await getDoc(doc(member('demo-001'), 'rondas/r1'));
    assert(ronda.data().season.end === '2026-11-24');
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1')));
  });

  test('nobody sets a season from a client', async () => {
    await assertFails(updateDoc(doc(member('demo-001'), 'rondas/r1'), { season: null }));
    await assertFails(updateDoc(doc(admin(), 'rondas/r2'), { season: { start: 'x', end: 'y' } }));
  });
});

function assert(condition) {
  if (!condition) throw new Error('assertion failed');
}
