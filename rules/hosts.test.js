// Hosts and attendance under firestore.rules (#47): the record of who came,
// `weeks/{isoWeek}.attendance`, is read by the admin only, never by a member, not even a host;
// the host's roll ("¿Quién vino hoy?") is read with `get` by the ronda's anfitrión and cola and
// by the admin. No client writes either: functions/attendance.py does, with the admin SDK.
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
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const NOW = new Date('2026-11-05T20:00:00Z');
const WEEK = '2026-W45';
const ANFITRION = 'demo-host-1';
const COLA = 'demo-host-2';
const MEMBER = 'demo-host-3';
const OTHER = 'demo-host-9';
const RECORD = `rondas/r1/weeks/${WEEK}`;
const ROLL = `rondas/r1/rolls/${WEEK}`;

let env;

before(async () => {
  const [host, port] = (process.env.FIRESTORE_EMULATOR_HOST ?? '127.0.0.1:8088').split(':');
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-hosts',
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
    const people = [
      { uid: ANFITRION, firstName: 'Mirta' },
      { uid: COLA, firstName: 'Jorge' },
      { uid: MEMBER, firstName: 'Ana' },
    ];
    const documents = {
      'rondas/r1': {
        status: 'active',
        slot: { day: 'thu', time: 'afternoon', hour: '16:00' },
        place: { name: 'frente al quiosco' },
        hosts: { anfitrion: ANFITRION, cola: COLA, anfitrionName: 'Mirta', colaName: 'Jorge' },
      },
      'rondas/r2': { status: 'active', slot: { day: 'tue', time: 'evening' } },
      'rondas/r2/members/demo-host-9': { brings: [], state: 'active', joinedAt: NOW },
      [`rondas/r2/rolls/${WEEK}`]: { week: WEEK, people: [], marks: {} },
      [RECORD]: {
        date: '2026-11-05',
        rsvp: { [ANFITRION]: 'yes', [MEMBER]: 'no' },
        attendance: { [ANFITRION]: true, [MEMBER]: false },
      },
      [ROLL]: {
        week: WEEK,
        date: '2026-11-05',
        people,
        marks: { [ANFITRION]: true, [MEMBER]: false },
        askedUid: ANFITRION,
        askedRole: 'anfitrion',
        askedAt: NOW,
      },
    };
    for (const uid of [ANFITRION, COLA, MEMBER]) {
      documents[`rondas/r1/members/${uid}`] = { brings: [], state: 'active', joinedAt: NOW };
    }
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const as = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();

describe('the record of who came', () => {
  test('the admin reads it', async () => {
    await assertSucceeds(getDoc(doc(admin(), RECORD)));
    await assertSucceeds(getDocs(collection(admin(), 'rondas/r1/weeks')));
  });

  test('no member reads it, not even the hosts who recorded it', async () => {
    for (const uid of [ANFITRION, COLA, MEMBER, OTHER]) {
      await assertFails(getDoc(doc(as(uid), RECORD)));
    }
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), RECORD)));
  });

  test('nobody writes it from a client, the admin included', async () => {
    await assertFails(updateDoc(doc(as(ANFITRION), RECORD), { [`attendance.${MEMBER}`]: true }));
    await assertFails(
      setDoc(doc(as(ANFITRION), RECORD), { attendance: { [MEMBER]: true } }, { merge: true }),
    );
    await assertFails(setDoc(doc(admin(), RECORD), { attendance: {} }, { merge: true }));
    await assertFails(deleteDoc(doc(admin(), RECORD)));
  });
});

describe("the host's roll", () => {
  test('the anfitrión, the cola and the admin get it', async () => {
    await assertSucceeds(getDoc(doc(as(ANFITRION), ROLL)));
    await assertSucceeds(getDoc(doc(as(COLA), ROLL)));
    await assertSucceeds(getDoc(doc(admin(), ROLL)));
  });

  test('a host may look for one that is not there yet', async () => {
    await assertSucceeds(getDoc(doc(as(ANFITRION), 'rondas/r1/rolls/2026-W46')));
  });

  test('nobody else: "Nadie más ve esta lista"', async () => {
    await assertFails(getDoc(doc(as(MEMBER), ROLL)));
    await assertFails(getDoc(doc(as(OTHER), ROLL)));
    await assertFails(getDoc(doc(env.unauthenticatedContext().firestore(), ROLL)));
  });

  test('a host of one ronda does not read another ronda\'s roll', async () => {
    await assertFails(getDoc(doc(as(ANFITRION), `rondas/r2/rolls/${WEEK}`)));
    await assertFails(getDoc(doc(as(OTHER), `rondas/r2/rolls/${WEEK}`)));
  });

  test('nobody lists the rolls, not even a host', async () => {
    await assertFails(getDocs(collection(as(ANFITRION), 'rondas/r1/rolls')));
  });

  test('nobody writes it from a client', async () => {
    await assertFails(updateDoc(doc(as(ANFITRION), ROLL), { [`marks.${COLA}`]: true }));
    await assertFails(setDoc(doc(as(COLA), 'rondas/r1/rolls/2026-W46'), { marks: {} }));
    await assertFails(setDoc(doc(admin(), ROLL), { marks: {} }, { merge: true }));
    await assertFails(deleteDoc(doc(admin(), ROLL)));
  });
});

describe("the ronda's place, hour and hosts", () => {
  test('its members read them on the ronda; nobody writes them from a client', async () => {
    await assertSucceeds(getDoc(doc(as(MEMBER), 'rondas/r1')));
    await assertFails(updateDoc(doc(as(ANFITRION), 'rondas/r1'), { 'slot.hour': '17:00' }));
    await assertFails(updateDoc(doc(admin(), 'rondas/r1'), { place: { name: 'la plaza' } }));
  });
});
