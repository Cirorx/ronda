// "Contar algo que pasó" under firestore.rules (#71): the send_report callable writes the
// report and the reporter's receipt with the admin SDK. Only the admin reads a report: not the
// reporter, not the person it is about, nobody else in their ronda. The reporter reads their
// own receipt and nobody else's. Who is kept apart and who is out of Ronda open to the admin
// only (rules/admin.test.js holds those paths to the exact claim). No client writes any of it.
//
//   cd rules && npm install && npm run test:emulator
//
// It runs on its own project id, like the other files.
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
  query,
  setDoc,
  updateDoc,
  where,
} from 'firebase/firestore';

const NOW = new Date('2026-11-02T15:00:00Z');
const REPORTER = 'demo-rep-ana';
const ABOUT = 'demo-rep-beto';
const NEIGHBOUR = 'demo-rep-cora';

// An invented report and its receipt, in the shape functions/reports.py writes them.
const REPORT = {
  reporterUid: REPORTER,
  reporterName: 'Ana',
  aboutUid: ABOUT,
  aboutName: 'Beto',
  rondaId: 'r1',
  rondaLine: 'Sábado a la tarde · mate en la rambla',
  tags: ['bothered'],
  text: 'Inventado: me insistió',
  additions: [],
  status: 'open',
  withdrawnAt: null,
  unread: true,
  createdAt: NOW,
  updatedAt: NOW,
};
const RECEIPT = { status: 'open', createdAt: NOW };

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-reports',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host,
      port: Number(port),
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'rondas/r1'), { status: 'active' });
    for (const uid of [REPORTER, ABOUT, NEIGHBOUR]) {
      await setDoc(doc(db, `rondas/r1/members/${uid}`), { state: 'active', joinedAt: NOW });
    }
    await setDoc(doc(db, 'reports/rep1'), REPORT);
    await setDoc(doc(db, `users/${REPORTER}/reports/rep1`), RECEIPT);
  });
});

after(() => env.cleanup());

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe('a report', () => {
  for (const [who, uid] of [
    ['the reporter', REPORTER],
    ['the person it is about', ABOUT],
    ['another member of the ronda', NEIGHBOUR],
  ]) {
    test(`${who} neither reads nor lists it`, async () => {
      await assertFails(getDoc(doc(as(uid), 'reports/rep1')));
      await assertFails(getDocs(collection(as(uid), 'reports')));
      await assertFails(
        getDocs(query(collection(as(uid), 'reports'), where('aboutUid', '==', uid))),
      );
    });
  }

  test('a signed-out visitor reads nothing', async () => {
    const db = env.unauthenticatedContext().firestore();
    await assertFails(getDoc(doc(db, 'reports/rep1')));
    await assertFails(getDoc(doc(db, `users/${REPORTER}/reports/rep1`)));
  });

  test('the admin counts the unread ones for the Admin tab', async () => {
    await assertSucceeds(
      getDocs(query(collection(admin(), 'reports'), where('unread', '==', true))),
    );
  });

  test('no client writes one, the reporter included', async () => {
    for (const db of [as(REPORTER), as(ABOUT), admin()]) {
      await assertFails(setDoc(doc(db, 'reports/rep2'), REPORT));
      await assertFails(updateDoc(doc(db, 'reports/rep1'), { status: 'archived' }));
      await assertFails(deleteDoc(doc(db, 'reports/rep1')));
    }
  });
});

describe("the reporter's receipt", () => {
  test('the reporter reads it and lists their own', async () => {
    await assertSucceeds(getDoc(doc(as(REPORTER), `users/${REPORTER}/reports/rep1`)));
    await assertSucceeds(getDocs(collection(as(REPORTER), `users/${REPORTER}/reports`)));
  });

  for (const [who, db] of [
    ['the person it is about', () => as(ABOUT)],
    ['another member', () => as(NEIGHBOUR)],
    ['the admin', admin],
  ]) {
    test(`${who} doesn't read it`, async () => {
      await assertFails(getDoc(doc(db(), `users/${REPORTER}/reports/rep1`)));
      await assertFails(getDocs(collection(db(), `users/${REPORTER}/reports`)));
    });
  }

  test('nobody writes it, the reporter included', async () => {
    for (const db of [as(REPORTER), admin()]) {
      await assertFails(setDoc(doc(db, `users/${REPORTER}/reports/rep9`), RECEIPT));
      await assertFails(
        updateDoc(doc(db, `users/${REPORTER}/reports/rep1`), { status: 'withdrawn' }),
      );
      await assertFails(deleteDoc(doc(db, `users/${REPORTER}/reports/rep1`)));
    }
  });
});

describe('who is kept apart and who is out', () => {
  test('the people involved read neither', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      await setDoc(doc(db, `avoid/${REPORTER}_${ABOUT}`), { uidA: REPORTER, uidB: ABOUT });
      await setDoc(doc(db, `removed/${ABOUT}`), { firstName: 'Beto', at: NOW });
    });
    for (const uid of [REPORTER, ABOUT]) {
      await assertFails(getDoc(doc(as(uid), `avoid/${REPORTER}_${ABOUT}`)));
      await assertFails(getDoc(doc(as(uid), `removed/${ABOUT}`)));
    }
  });
});
