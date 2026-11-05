// The seat catalogue under firestore.rules: a signed-in member reads the
// seats and the catalogue's version, and nobody writes either from a phone.
//
//   cd firebase/tests && npm install && npm test
//
// It runs on its own project id, since node runs test files in parallel.
import { after, before, describe, test } from 'node:test';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { collection, doc, getDoc, getDocs, setDoc } from 'firebase/firestore';

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-seat-catalog',
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      host: '127.0.0.1',
      port: 8088,
    },
  });
  await env.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await setDoc(doc(db, 'config/seat_catalog'), { version: 'invented', seats: 1 });
    await setDoc(doc(db, 'config/other'), { secret: true });
    await setDoc(doc(db, 'seat_facts/palermo_mate'), { barrio: 'palermo' });
  });
});

after(() => env.cleanup());

const anyone = () => env.unauthenticatedContext().firestore();
const member = () => env.authenticatedContext('demo-seat-1').firestore();

describe('a signed-in member', () => {
  test('gets the catalogue version', async () => {
    await assertSucceeds(getDoc(doc(member(), 'config/seat_catalog')));
  });

  test('lists the seats', async () => {
    await assertSucceeds(getDocs(collection(member(), 'seat_facts')));
  });

  test('cannot write the version or a seat', async () => {
    await assertFails(setDoc(doc(member(), 'config/seat_catalog'), { version: 'mine' }));
    await assertFails(setDoc(doc(member(), 'seat_facts/palermo_mate'), { barrio: 'x' }));
  });

  test('cannot get any other config document', async () => {
    await assertFails(getDoc(doc(member(), 'config/other')));
  });
});

describe('anyone signed out', () => {
  test('cannot get the catalogue version', async () => {
    await assertFails(getDoc(doc(anyone(), 'config/seat_catalog')));
  });
});
