// users/{uid} and users/{uid}/private/eligible under firestore.rules: what a voice sign-up
// leaves in Firestore, and the ways a client might slip a need, a mood or a voice note into it.
//
//   cd rules && npm install && npm test
//
// A voice sign-up writes Firestore from the phone only, the way packages/ronda_api does: the
// terms when a welcome door is tapped, then on "Está bien, guardalo" the eligible seat ids and
// the profile read back from the note. The extract callable writes nothing and deletes the note
// (functions/tests/test_main.py), so these writes are everything the sign-up leaves.
//
// Its own project id: node's runner runs test files in parallel and each clears its project.
import { after, before, beforeEach, describe, test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import { Timestamp, doc, getDoc, serverTimestamp, setDoc } from 'firebase/firestore';

const PROJECT = 'demo-ronda-users';
const EMULATOR = { host: '127.0.0.1', port: 8088 };
const UID = 'demo-voice-001';
const USER = `users/${UID}`;
const ELIGIBLE = `${USER}/private/eligible`;

const TERMS = {
  version: '2026-10-27',
  acceptedAt: Timestamp.fromDate(new Date('2026-10-29T13:00:00Z')),
};
// What extract read from an invented note, in the shape the read-back saves.
const READ_BACK = {
  firstName: 'Graciela',
  ageBand: '60-69',
  barrio: 'solymar-norte',
  pretexts: ['mate', 'truco'],
  slots: ['tue-afternoon', 'sat-morning'],
  brings: ['termo'],
};
const SEAT_IDS = [
  'solymar-norte_mate_tue-afternoon',
  'solymar-sur_mate_tue-afternoon',
  'solymar-norte_truco_sat-morning',
];
const SENSITIVE = {
  needs: ['bad-knee', 'no-car'],
  mood: 'low',
  audio: `audio/${UID}/note-1.wav`,
};

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: PROJECT,
    firestore: {
      rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
      ...EMULATOR,
    },
  });
});

after(() => env.cleanup());

beforeEach(() => env.clearFirestore());

const member = (uid = UID) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

// The phone's three writes (RondaApi.saveTerms, writeEligibleSeatIds, saveProfile).
const saveTerms = (db, terms = TERMS) => setDoc(doc(db, USER), { terms }, { merge: true });
const saveEligible = (db, fields = {}) =>
  setDoc(doc(db, ELIGIBLE), { seatIds: SEAT_IDS, updatedAt: serverTimestamp(), ...fields });
const saveProfile = (db, fields = {}) =>
  setDoc(
    doc(db, USER),
    { ...READ_BACK, createdAt: serverTimestamp(), ...fields },
    { merge: true },
  );

function seed(documents) {
  return env.withSecurityRulesDisabled(async (context) => {
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(context.firestore(), path), fields);
    }
  });
}

// Every document in the project, read past the rules as the emulator's owner.
async function everyDocument() {
  const response = await fetch(
    `http://${EMULATOR.host}:${EMULATOR.port}/v1/projects/${PROJECT}` +
      '/databases/%28default%29/documents:runQuery',
    {
      method: 'POST',
      headers: { Authorization: 'Bearer owner', 'Content-Type': 'application/json' },
      body: JSON.stringify({ structuredQuery: { from: [{ allDescendants: true }] } }),
    },
  );
  assert.equal(response.status, 200);
  return (await response.json()).flatMap(({ document }) => (document ? [document] : []));
}

// Every field name at any depth and every string value in a REST document's fields.
function namesAndStrings(fields, found = { names: [], strings: [] }) {
  for (const [name, value] of Object.entries(fields ?? {})) {
    found.names.push(name);
    walk(value, found);
  }
  return found;
}

function walk(value, found) {
  if ('stringValue' in value) found.strings.push(value.stringValue);
  if ('mapValue' in value) namesAndStrings(value.mapValue.fields, found);
  for (const item of value.arrayValue?.values ?? []) walk(item, found);
}

describe('after a voice sign-up', () => {
  beforeEach(async () => {
    const db = member();
    await assertSucceeds(saveTerms(db));
    await assertSucceeds(saveEligible(db));
    await assertSucceeds(saveProfile(db));
  });

  test('Firestore holds the profile and the eligible seat ids, nothing else', async () => {
    const paths = (await everyDocument()).map(({ name }) => name.split('/documents/')[1]);

    assert.deepEqual(paths.sort(), [USER, ELIGIBLE]);
  });

  test('no document carries needs, a mood or an audio path', async () => {
    for (const document of await everyDocument()) {
      const { names, strings } = namesAndStrings(document.fields);

      assert.ok(names.length > 0);
      assert.deepEqual(names.filter((name) => /needs|mood|audio/i.test(name)), []);
      assert.deepEqual(strings.filter((text) => /audio\/|\.wav/i.test(text)), []);
    }
  });
});

describe('users/{uid}', () => {
  test('refuses needs, a mood or audio with the terms or the profile', async () => {
    const db = member();
    for (const [name, value] of Object.entries(SENSITIVE)) {
      await assertFails(setDoc(doc(db, USER), { terms: TERMS, [name]: value }));
    }
    await assertSucceeds(saveTerms(db));
    for (const [name, value] of Object.entries(SENSITIVE)) {
      await assertFails(saveProfile(db, { [name]: value }));
    }
    await assertSucceeds(saveProfile(db));
  });

  test('refuses a voice note or a transcript under any other name', async () => {
    const db = member();
    await saveTerms(db);
    for (const name of ['audioPath', 'voiceNote', 'notePath', 'transcript', 'address']) {
      await assertFails(saveProfile(db, { [name]: SENSITIVE.audio }));
    }
  });

  test('refuses a need, a mood or audio inside a list', async () => {
    const db = member();
    await saveTerms(db);
    for (const list of ['slots', 'pretexts', 'brings']) {
      for (const [name, value] of Object.entries(SENSITIVE)) {
        await assertFails(saveProfile(db, { [list]: [...READ_BACK[list], { [name]: value }] }));
      }
    }
  });

  test('refuses words, numbers or a path where an id belongs', async () => {
    const db = member();
    await saveTerms(db);
    for (const fields of [
      { brings: ['no puedo caminar'] },
      { brings: [SENSITIVE.audio] },
      { pretexts: ['Mate'] },
      { pretexts: [5] },
      { slots: ['tue'] },
      { slots: ['tue-night'] },
    ]) {
      await assertFails(saveProfile(db, fields));
    }
    await assertSucceeds(saveProfile(db, { brings: [], pretexts: ['futbol5'] }));
  });

  test('refuses anything else inside the terms', async () => {
    await assertFails(saveTerms(member(), { ...TERMS, needs: SENSITIVE.needs }));
    await assertFails(saveTerms(member(), { ...TERMS, audio: SENSITIVE.audio }));
  });

  test('is read and written by its owner only', async () => {
    await seed({ [USER]: { terms: TERMS, ...READ_BACK } });

    await assertSucceeds(getDoc(doc(member(), USER)));
    await assertFails(getDoc(doc(member('demo-other'), USER)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), USER)));
    await assertFails(saveProfile(member('demo-other')));
  });
});

describe('users/{uid}/private/eligible', () => {
  const seatIds = (count) =>
    Array.from({ length: count }, (_, i) => `barrio-${i}_mate_mon-morning`);

  test('takes exactly the seat ids and the server time, up to 1000 ids', async () => {
    await assertSucceeds(saveEligible(member()));
    await assertSucceeds(saveEligible(member(), { seatIds: [] }));
    await assertSucceeds(saveEligible(member(), { seatIds: seatIds(1000) }));
  });

  test('refuses needs, a mood or audio beside the ids', async () => {
    for (const [name, value] of Object.entries(SENSITIVE)) {
      await assertFails(saveEligible(member(), { [name]: value }));
    }
  });

  test('refuses a need inside the ids, or anything but a seat id', async () => {
    for (const ids of [
      [...SEAT_IDS, { needs: SENSITIVE.needs }],
      [...SEAT_IDS, 'rodilla mala'],
      [...SEAT_IDS, SENSITIVE.audio],
      [...SEAT_IDS, 7],
      ['solymar-norte_mate'],
    ]) {
      await assertFails(saveEligible(member(), { seatIds: ids }));
    }
  });

  test("refuses more than 1000 ids, a missing time or the phone's clock", async () => {
    await assertFails(saveEligible(member(), { seatIds: seatIds(1001) }));
    await assertFails(setDoc(doc(member(), ELIGIBLE), { seatIds: SEAT_IDS }));
    await assertFails(saveEligible(member(), { updatedAt: new Date() }));
  });

  test('is read by no client, not its owner and not the admin', async () => {
    await seed({ [ELIGIBLE]: { seatIds: SEAT_IDS, updatedAt: new Date() } });

    await assertFails(getDoc(doc(member(), ELIGIBLE)));
    await assertFails(getDoc(doc(admin(), ELIGIBLE)));
    await assertFails(getDoc(doc(member('demo-other'), ELIGIBLE)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), ELIGIBLE)));
  });

  test('is written by its owner only', async () => {
    await assertFails(saveEligible(member('demo-other')));
    await assertFails(saveEligible(admin()));
    await assertFails(saveEligible(env.unauthenticatedContext().firestore()));
  });

  test('opens no other private document or subcollection', async () => {
    const db = member();
    for (const path of [
      `${USER}/private/needs`,
      `${USER}/needs/knee`,
      `${USER}/audio/note-1`,
      `${ELIGIBLE}/history/1`,
    ]) {
      await assertFails(setDoc(doc(db, path), { seatIds: SEAT_IDS }));
    }
  });
});
