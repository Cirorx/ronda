// Proposals and rondas under firestore.rules: nothing is visible to a member
// before Aprobar, and afterwards each member reads only their own ronda.
//
//   cd rules && npm install && npm test
//
// The documents are written the way the approve_proposal callable writes them
// (functions/proposals.py), with the rules off, as the admin SDK skips them.
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
} from 'firebase/firestore';

const NOW = new Date('2026-10-27T15:00:00Z');
const PROPOSAL = {
  status: 'pending',
  groups: [
    {
      id: 'lagomar-sur_mate_sat-afternoon',
      members: [
        { uid: 'demo-001', firstName: 'Marta', ageBand: '60-69', distanceBlocks: 2 },
        { uid: 'demo-002', firstName: 'Raúl', ageBand: '70-79', distanceBlocks: 4 },
      ],
    },
  ],
  createdAt: NOW,
};

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-rules',
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
  await seed({ 'proposals/p1': PROPOSAL });
});

function seed(documents) {
  return env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
}

function approve() {
  return seed({
    'rondas/r1': { seatId: 'lagomar-sur_mate_sat-afternoon', status: 'forming', size: 2 },
    'rondas/r1/members/demo-001': { brings: ['pan'], state: 'active', joinedAt: NOW },
    'rondas/r1/members/demo-002': { brings: [], state: 'active', joinedAt: NOW },
    'proposals/p1': { ...PROPOSAL, status: 'approved', rondaIds: ['r1'] },
  });
}

const member = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe('before Aprobar', () => {
  test('a proposed member cannot read the proposal or list proposals', async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'proposals/p1')));
    await assertFails(getDocs(collection(member('demo-001'), 'proposals')));
  });

  test('a signed-out visitor cannot read it either', async () => {
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), 'proposals/p1')));
  });

  test('a claim other than admin: true is not enough', async () => {
    const db = env.authenticatedContext('demo-003', { admin: 'yes' }).firestore();
    await assertFails(getDoc(doc(db, 'proposals/p1')));
  });

  test('no member can see a ronda, because none exists', async () => {
    await assertFails(getDocs(collection(member('demo-001'), 'rondas')));
    await assertFails(getDoc(doc(member('demo-001'), 'rondas/r1')));
  });

  test('the admin reads the proposal', async () => {
    await assertSucceeds(getDoc(doc(admin(), 'proposals/p1')));
  });

  test('not even the admin writes a proposal or a ronda from a client', async () => {
    await assertFails(setDoc(doc(admin(), 'proposals/p2'), PROPOSAL));
    await assertFails(setDoc(doc(admin(), 'proposals/p1'), { status: 'approved' }));
    await assertFails(deleteDoc(doc(admin(), 'proposals/p1')));
    await assertFails(setDoc(doc(admin(), 'rondas/r1'), { status: 'forming' }));
  });

  test('a member cannot write themselves into a ronda', async () => {
    await assertFails(
      setDoc(doc(member('demo-001'), 'rondas/r1/members/demo-001'), { state: 'active' }),
    );
  });
});

describe('after Aprobar', () => {
  beforeEach(approve);

  test('the ronda documents exist', async () => {
    await env.withSecurityRulesDisabled(async (context) => {
      const db = context.firestore();
      const ronda = await getDoc(doc(db, 'rondas/r1'));
      const members = await getDocs(collection(db, 'rondas/r1/members'));
      if (!ronda.exists() || members.size !== 2) throw new Error('ronda not written');
    });
  });

  test('a member reads their ronda and who is in it', async () => {
    await assertSucceeds(getDoc(doc(member('demo-001'), 'rondas/r1')));
    await assertSucceeds(getDocs(collection(member('demo-001'), 'rondas/r1/members')));
  });

  test('someone outside it reads neither', async () => {
    await assertFails(getDoc(doc(member('demo-009'), 'rondas/r1')));
    await assertFails(getDocs(collection(member('demo-009'), 'rondas/r1/members')));
  });

  test('a member still cannot read the proposal', async () => {
    await assertFails(getDoc(doc(member('demo-001'), 'proposals/p1')));
  });

  test('a member cannot list every ronda', async () => {
    await assertFails(getDocs(collection(member('demo-001'), 'rondas')));
  });

  test('a member cannot change or leave the ronda from a client', async () => {
    await assertFails(setDoc(doc(member('demo-001'), 'rondas/r1'), { status: 'ended' }));
    await assertFails(deleteDoc(doc(member('demo-001'), 'rondas/r1/members/demo-002')));
  });
});
