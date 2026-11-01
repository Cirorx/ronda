// ¿Alguien se suma? (#57) under firestore.rules: each member reads only their own plan card;
// the plans themselves, with who joined each, stay closed to every client, the author's
// included; a member who left or another ronda's member reads nothing; and no client writes a
// card or a plan.
//
//   cd rules && npm install
//   FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 npm test
//
// It runs on its own project id, since node runs test files in parallel. Every person is
// invented.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, deleteDoc, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

const AUTHOR = 'demo-sp-author';
const JOINER = 'demo-sp-joiner';
const BYSTANDER = 'demo-sp-bystander';
const LEFT = 'demo-sp-left';
const OTHER = 'demo-sp-other';

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-shared-plans',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host,
      port: Number(port),
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'rondas/r1'), { pretext: 'mate', barrio: 'el-pinar-sur' });
    for (const uid of [AUTHOR, JOINER, BYSTANDER]) {
      await setDoc(doc(db, `rondas/r1/members/${uid}`), { state: 'active' });
    }
    await setDoc(doc(db, `rondas/r1/members/${LEFT}`), { state: 'left' });
    await setDoc(doc(db, 'rondas/r2'), { pretext: 'truco' });
    await setDoc(doc(db, `rondas/r2/members/${OTHER}`), { state: 'active' });
    await setDoc(doc(db, `rondas/r1/shared_plans/${AUTHOR}`), {
      author: AUTHOR,
      firstName: 'Ana',
      activity: 'Caminar por la rambla',
      joined: { [JOINER]: { firstName: 'Bruno' } },
    });
    await setDoc(doc(db, `rondas/r1/plan_cards/${AUTHOR}`), {
      plans: [],
      mine: { activity: 'Caminar por la rambla', joined: ['Bruno'] },
    });
    await setDoc(doc(db, `rondas/r1/plan_cards/${JOINER}`), {
      plans: [{ id: AUTHOR, firstName: 'Ana', joined: true }],
      mine: null,
    });
    await setDoc(doc(db, `rondas/r1/plan_cards/${LEFT}`), { plans: [], mine: null });
  });
});

after(() => env.cleanup());

const firestoreOf = (uid) => env.authenticatedContext(uid).firestore();

describe('a plan card', () => {
  test('is read by its owner, a member of the ronda', async () => {
    await assertSucceeds(getDoc(doc(firestoreOf(AUTHOR), `rondas/r1/plan_cards/${AUTHOR}`)));
    await assertSucceeds(getDoc(doc(firestoreOf(JOINER), `rondas/r1/plan_cards/${JOINER}`)));
  });

  test('is not read by another member, so nobody learns who joined', async () => {
    for (const uid of [JOINER, BYSTANDER]) {
      await assertFails(getDoc(doc(firestoreOf(uid), `rondas/r1/plan_cards/${AUTHOR}`)));
    }
    await assertFails(getDoc(doc(firestoreOf(BYSTANDER), `rondas/r1/plan_cards/${JOINER}`)));
  });

  test('is not listed', async () => {
    await assertFails(getDocs(collection(firestoreOf(AUTHOR), 'rondas/r1/plan_cards')));
  });

  test("is not read by a member who left, another ronda's member or a signed-out visitor", async () => {
    await assertFails(getDoc(doc(firestoreOf(LEFT), `rondas/r1/plan_cards/${LEFT}`)));
    await assertFails(getDoc(doc(firestoreOf(OTHER), `rondas/r1/plan_cards/${OTHER}`)));
    await assertFails(getDoc(doc(firestoreOf(OTHER), `rondas/r1/plan_cards/${AUTHOR}`)));
    await assertFails(
      getDoc(doc(env.unauthenticatedContext().firestore(), `rondas/r1/plan_cards/${AUTHOR}`)),
    );
  });
});

describe('the shared plans themselves', () => {
  test('are closed to every client, even the author', async () => {
    for (const uid of [AUTHOR, JOINER, BYSTANDER, LEFT, OTHER]) {
      await assertFails(getDoc(doc(firestoreOf(uid), `rondas/r1/shared_plans/${AUTHOR}`)));
      await assertFails(getDocs(collection(firestoreOf(uid), 'rondas/r1/shared_plans')));
    }
  });
});

describe('writing', () => {
  test('no client writes a card or a plan', async () => {
    const db = firestoreOf(AUTHOR);
    await assertFails(setDoc(doc(db, `rondas/r1/plan_cards/${AUTHOR}`), { plans: [], mine: null }));
    await assertFails(deleteDoc(doc(db, `rondas/r1/plan_cards/${AUTHOR}`)));
    await assertFails(setDoc(doc(db, `rondas/r1/shared_plans/${AUTHOR}`), { activity: 'x' }));
    await assertFails(
      setDoc(doc(firestoreOf(JOINER), `rondas/r1/shared_plans/${AUTHOR}`), { joined: {} }),
    );
  });
});
