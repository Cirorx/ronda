// The organiser agent under firestore.rules (#49): the trace is the admin's, the acta its
// ronda's, a rain proposal its host's, and [Algo estuvo mal] the one thing a member writes.
//
//   cd rules && npm install && npm test
//
// The documents are written the way functions/rain.py and functions/organiser/ write them, with
// the rules off, as the admin SDK skips them.
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
  orderBy,
  query,
  serverTimestamp,
  setDoc,
  updateDoc,
} from 'firebase/firestore';

const NOW = new Date('2026-11-04T21:00:00Z');
const WEEK = '2026-W45';
const RUN = `r1_${WEEK}_rain`;

let env;

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-ronda-agent',
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
      'rondas/r1': { seatId: 'el-pinar-sur_mate_thu-afternoon', status: 'active', size: 2 },
      'rondas/r1/members/demo-101': { brings: ['termo'], state: 'active', joinedAt: NOW },
      'rondas/r1/members/demo-102': { brings: ['pan'], state: 'active', joinedAt: NOW },
      'rondas/r2': { seatId: 'lagomar-sur_truco_tue-evening', status: 'active', size: 1 },
      'rondas/r2/members/demo-109': { brings: [], state: 'active', joinedAt: NOW },
      [`agent_runs/${RUN}`]: { job: 'rain_check', rondaId: 'r1', week: WEEK, startedAt: NOW },
      [`agent_runs/${RUN}/steps/001`]: { n: 1, ts: NOW, kind: 'tool', tool: 'get_forecast' },
      [`acta/r1/entries/${RUN}-001`]: {
        week: WEEK,
        ts: NOW,
        tool: 'get_forecast',
        summary: 'Miró el pronóstico del jueves 5/11 a las 16:00: lluvia 80%.',
        decidedBy: 'agent',
        runId: RUN,
      },
      'acta/r1/flags/demo-102': { week: WEEK, at: NOW },
      [`rondas/r1/moves/${WEEK}`]: {
        week: WEEK,
        hostUid: 'demo-101',
        status: 'pending',
        options: [{ id: 'asIs', label: 'Vamos igual', message: 'Vamos igual.' }],
      },
      'places/salon': { name: 'el Salón Comunal', covered: true, kind: 'public' },
      'users/demo-102/private/agent': { introducedAt: NOW },
    };
    for (const [path, fields] of Object.entries(documents)) {
      await setDoc(doc(db, path), fields);
    }
  });
});

const member = (uid) => env.authenticatedContext(uid).firestore();
const admin = () => env.authenticatedContext('demo-admin', { admin: true }).firestore();
const visitor = () => env.unauthenticatedContext().firestore();

describe('the trace', () => {
  test('the admin lists the runs and reads their steps', async () => {
    const runs = query(collection(admin(), 'agent_runs'), orderBy('startedAt', 'desc'));
    await assertSucceeds(getDocs(runs));
    await assertSucceeds(getDoc(doc(admin(), `agent_runs/${RUN}`)));
    await assertSucceeds(getDocs(query(collection(admin(), `agent_runs/${RUN}/steps`), orderBy('n'))));
  });

  test('no member, not even of that ronda, and no visitor reads any of it', async () => {
    for (const db of [member('demo-101'), member('demo-109'), visitor()]) {
      await assertFails(getDocs(collection(db, 'agent_runs')));
      await assertFails(getDoc(doc(db, `agent_runs/${RUN}`)));
      await assertFails(getDocs(collection(db, `agent_runs/${RUN}/steps`)));
    }
  });

  test('nobody writes it from a client, not even the admin', async () => {
    await assertFails(setDoc(doc(admin(), `agent_runs/${RUN}/steps/002`), { n: 2 }));
    await assertFails(updateDoc(doc(admin(), `agent_runs/${RUN}`), { status: 'done' }));
    await assertFails(deleteDoc(doc(admin(), `agent_runs/${RUN}`)));
  });
});

describe('the acta', () => {
  test("a member lists their ronda's acta", async () => {
    const entries = query(collection(member('demo-102'), 'acta/r1/entries'), orderBy('ts', 'desc'));
    await assertSucceeds(getDocs(entries));
  });

  test('a member of another ronda, a visitor or the admin cannot', async () => {
    for (const db of [member('demo-109'), visitor(), admin()]) {
      await assertFails(getDocs(collection(db, 'acta/r1/entries')));
    }
  });

  test('nobody writes an entry from a client', async () => {
    const entry = { week: WEEK, ts: NOW, tool: 'log_acta', summary: 'x', decidedBy: 'agent' };
    await assertFails(setDoc(doc(member('demo-101'), 'acta/r1/entries/mine'), entry));
    await assertFails(deleteDoc(doc(member('demo-101'), `acta/r1/entries/${RUN}-001`)));
  });
});

describe('[Algo estuvo mal]', () => {
  const flag = (uid, fields) => setDoc(doc(member(uid), `acta/r1/flags/${uid}`), fields);

  test('a member records the week they read, at the server time, and again later', async () => {
    await assertSucceeds(flag('demo-101', { week: WEEK, at: serverTimestamp() }));
    await assertSucceeds(flag('demo-101', { week: '2026-W46', at: serverTimestamp() }));
  });

  test('only exactly that, and only under their own uid', async () => {
    await assertFails(flag('demo-101', { week: WEEK, at: NOW }));
    await assertFails(flag('demo-101', { week: 'jueves', at: serverTimestamp() }));
    await assertFails(flag('demo-101', { week: WEEK, at: serverTimestamp(), text: 'mal' }));
    await assertFails(flag('demo-101', { at: serverTimestamp() }));
    await assertFails(
      setDoc(doc(member('demo-101'), 'acta/r1/flags/demo-102'), { week: WEEK, at: serverTimestamp() }),
    );
  });

  test('someone outside the ronda cannot', async () => {
    await assertFails(flag('demo-109', { week: WEEK, at: serverTimestamp() }));
  });

  test('the admin reads them; the member who tapped and the others cannot', async () => {
    await assertSucceeds(getDocs(collection(admin(), 'acta/r1/flags')));
    await assertFails(getDoc(doc(member('demo-102'), 'acta/r1/flags/demo-102')));
    await assertFails(getDocs(collection(member('demo-101'), 'acta/r1/flags')));
  });

  test('nobody deletes one', async () => {
    await assertFails(deleteDoc(doc(member('demo-102'), 'acta/r1/flags/demo-102')));
  });
});

describe('a rain proposal', () => {
  const path = `rondas/r1/moves/${WEEK}`;

  test('its host reads it', async () => {
    await assertSucceeds(getDoc(doc(member('demo-101'), path)));
  });

  test('another member, a visitor or the admin cannot', async () => {
    for (const db of [member('demo-102'), member('demo-109'), visitor(), admin()]) {
      await assertFails(getDoc(doc(db, path)));
    }
  });

  test('nobody lists them, not even the host', async () => {
    await assertFails(getDocs(collection(member('demo-101'), 'rondas/r1/moves')));
  });

  test('the host picks through the callable, never by writing it', async () => {
    await assertFails(updateDoc(doc(member('demo-101'), path), { status: 'decided' }));
    await assertFails(deleteDoc(doc(member('demo-101'), path)));
  });
});

describe('what stays on the server', () => {
  test('nobody reads the covered places or what the agent remembers of a person', async () => {
    for (const db of [member('demo-101'), member('demo-102'), admin()]) {
      await assertFails(getDoc(doc(db, 'places/salon')));
      await assertFails(getDoc(doc(db, 'users/demo-102/private/agent')));
      await assertFails(getDoc(doc(db, `rondas/r1/weeks/${WEEK}`)));
    }
  });
});
