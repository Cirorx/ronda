// The buddy under firestore.rules (#50, the rule from #9): the card that tells a buddy someone
// missed a week ("Graciela no vino el jueves…") is read by that buddy only, who may close it and
// change nothing else; who was prompted stays closed; the choice lives on the chooser's own
// users/{uid}.buddyUid, which nobody else reads. functions/buddy.py writes the rest with the
// admin SDK.
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
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const NOW = new Date('2026-11-06T13:00:00Z');
const WEEK = '2026-W45';
const BUDDY = 'demo-buddy-1';
const MISSED = 'demo-buddy-2';
const MEMBER = 'demo-buddy-3';
const OTHER = 'demo-buddy-9';
const CARD = `rondas/r1/buddy_asks/${BUDDY}`;
const PROMPTS = `rondas/r1/buddy_prompts/${WEEK}`;

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-buddy',
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
      'rondas/r1': { status: 'active', slot: { day: 'thu', time: 'afternoon' } },
      [CARD]: {
        status: 'open',
        asks: [{ firstName: 'Graciela', day: 'thu', week: WEEK, at: NOW }],
        updatedAt: NOW,
      },
      [PROMPTS]: { prompted: { [MISSED]: NOW } },
      [`users/${MISSED}`]: { firstName: 'Graciela', buddyUid: BUDDY },
    };
    for (const uid of [BUDDY, MISSED, MEMBER]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
    }
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe("the buddy's card", () => {
  test('the buddy reads it, and may look for one that is not there yet', async () => {
    await assertSucceeds(getDoc(doc(as(BUDDY), CARD)));
    await assertSucceeds(getDoc(doc(as(MEMBER), `rondas/r1/buddy_asks/${MEMBER}`)));
  });

  test('nobody else: not the member who missed, not the ronda, not the admin', async () => {
    for (const reader of [as(MISSED), as(MEMBER), as(OTHER), admin()]) {
      await assertFails(getDoc(doc(reader, CARD)));
    }
    await assertFails(getDocs(collection(as(BUDDY), 'rondas/r1/buddy_asks')));
  });

  test('the buddy closes it, with the time it was closed', async () => {
    await assertSucceeds(
      updateDoc(doc(as(BUDDY), CARD), { status: 'closed', closedAt: serverTimestamp() }),
    );
  });

  test('and changes nothing else', async () => {
    const card = doc(as(BUDDY), CARD);
    await assertFails(updateDoc(card, { status: 'open', closedAt: serverTimestamp() }));
    await assertFails(updateDoc(card, { status: 'closed', closedAt: NOW }));
    await assertFails(
      updateDoc(card, { status: 'closed', closedAt: serverTimestamp(), asks: [] }),
    );
    await assertFails(deleteDoc(card));
    await assertFails(
      setDoc(doc(as(MEMBER), `rondas/r1/buddy_asks/${MEMBER}`), {
        status: 'closed',
        closedAt: serverTimestamp(),
      }),
    );
  });

  test('a buddy who left the ronda no longer reads it', async () => {
    await env.withSecurityRulesDisabled((context) =>
      deleteDoc(doc(context.firestore(), `rondas/r1/members/${BUDDY}`)),
    );
    await assertFails(getDoc(doc(as(BUDDY), CARD)));
  });
});

describe('who was prompted and who chose whom', () => {
  test('the prompts stay closed to every client', async () => {
    for (const reader of [as(BUDDY), as(MISSED), admin()]) {
      await assertFails(getDoc(doc(reader, PROMPTS)));
    }
  });

  test('a choice is read by the one who made it only', async () => {
    await assertSucceeds(getDoc(doc(as(MISSED), `users/${MISSED}`)));
    await assertFails(getDoc(doc(as(BUDDY), `users/${MISSED}`)));
  });
});
