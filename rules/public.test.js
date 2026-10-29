// What the public pages may read under firestore.rules: anyone gets one
// barrio's Cerca tuyo counts, and nothing else opens. A tear-off flyer stays
// closed even to signed-in members: the flyer_landing function counts its
// scans and answers its page with the admin SDK.
//
//   cd rules && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel.
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
  increment,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

// Invented counts, in the shape functions/cerca_tuyo.py writes.
const COUNTS = {
  barrio: 'solymar-norte',
  rondas: [
    {
      pretext: 'mate',
      slot: 'sat-afternoon',
      ageFrom: 30,
      ageTo: 79,
      members: 4,
      cap: 6,
      waiting: 0,
    },
  ],
  waiting: [{ pretext: 'caminata', count: 3 }],
};
const FLYER = { barrio: 'solymar-norte', label: 'Invented spot', scans: 0 };

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-public',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8088,
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'cerca/solymar-norte'), COUNTS);
    await setDoc(doc(db, 'flyers/k3m9x2pq'), FLYER);
    await setDoc(doc(db, 'rondas/demo-ronda'), { barrio: 'solymar-norte' });
    await setDoc(doc(db, 'users/demo-pub-1'), { firstName: 'Vecina' });
    await setDoc(doc(db, 'seat_facts/solymar-norte_mate_sat-afternoon'), {
      barrio: 'solymar-norte',
    });
  });
});

after(() => env.cleanup());

const anyone = () => env.unauthenticatedContext().firestore();
const member = () => env.authenticatedContext('demo-pub-1').firestore();

describe('anyone, signed in or not', () => {
  test('gets a barrio\'s counts', async () => {
    await assertSucceeds(getDoc(doc(anyone(), 'cerca/solymar-norte')));
    await assertSucceeds(getDoc(doc(member(), 'cerca/solymar-norte')));
  });

  test('gets a barrio that has no counts yet', async () => {
    await assertSucceeds(getDoc(doc(anyone(), 'cerca/el-pinar-sur')));
  });

  test('cannot list every barrio at once', async () => {
    await assertFails(getDocs(collection(anyone(), 'cerca')));
  });

  test('cannot write the counts', async () => {
    for (const db of [anyone(), member()]) {
      await assertFails(setDoc(doc(db, 'cerca/solymar-norte'), COUNTS));
      await assertFails(setDoc(doc(db, 'cerca/shangrila'), COUNTS));
      await assertFails(deleteDoc(doc(db, 'cerca/solymar-norte')));
    }
  });
});

describe('a tear-off flyer', () => {
  test('is read by nobody from a client', async () => {
    await assertFails(getDoc(doc(anyone(), 'flyers/k3m9x2pq')));
    await assertFails(getDoc(doc(member(), 'flyers/k3m9x2pq')));
    await assertFails(getDocs(collection(anyone(), 'flyers')));
  });

  test('counts no scan from a client', async () => {
    for (const db of [anyone(), member()]) {
      await assertFails(updateDoc(doc(db, 'flyers/k3m9x2pq'), { scans: increment(1) }));
      await assertFails(setDoc(doc(db, 'flyers/newflyer'), FLYER));
    }
  });
});

describe('everything else stays closed to a signed-out visitor', () => {
  for (const path of [
    'rondas/demo-ronda',
    'users/demo-pub-1',
    'seat_facts/solymar-norte_mate_sat-afternoon',
    'proposals/any',
    'waitlists/solymar-norte_mate_sat-afternoon',
  ]) {
    test(`cannot get ${path}`, async () => {
      await assertFails(getDoc(doc(anyone(), path)));
    });
  }

  for (const path of ['rondas', 'users', 'seat_facts']) {
    test(`cannot list ${path}`, async () => {
      await assertFails(getDocs(collection(anyone(), path)));
    });
  }
});
