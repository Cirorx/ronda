// Seeds a first visit for the demo account the flow just signed in with: an invented ronda
// that meets tomorrow at 16:00 frente al quiosco, Jorge (invented, `flow-jorge`) as its
// anfitrión, and the account added to it as a newcomer, the way the admin's "Sumar a esta
// ronda" leaves it, with the welcome functions/first_visit.py writes (nobody picked yet, so
// whoever opens waits: Jorge). It writes through the Firestore emulator's REST API with the
// `owner` token, which skips the rules, and runs on the Mac, so 127.0.0.1 is the emulator's
// own address even when the app reaches it as 10.0.2.2. Every person and place is invented.
const BASE =
  'http://127.0.0.1:8088/v1/projects/ronda-uy/databases/(default)/documents';
const HEADERS = { Authorization: 'Bearer owner', 'Content-Type': 'application/json' };
const RONDA = 'flow-first-visit';
const JORGE = 'flow-jorge';

function value(v) {
  if (v instanceof Date) return { timestampValue: v.toISOString() };
  if (typeof v === 'string') return { stringValue: v };
  if (typeof v === 'boolean') return { booleanValue: v };
  if (typeof v === 'number') return { integerValue: String(v) };
  if (Array.isArray(v)) return { arrayValue: { values: v.map(value) } };
  const fields = {};
  for (const key of Object.keys(v)) fields[key] = value(v[key]);
  return { mapValue: { fields } };
}

function write(path, fields) {
  const response = http.request(`${BASE}/${path}`, {
    method: 'PATCH',
    headers: HEADERS,
    body: JSON.stringify(value(fields).mapValue),
  });
  if (response.status !== 200) {
    throw new Error(`${path}: ${response.status} ${response.body}`);
  }
}

// The account the flow signed in with: the one profile that isn't an invented `demo-` one.
const users = json(http.get(`${BASE}/users?pageSize=300`, { headers: HEADERS }).body);
const mine = (users.documents || [])
  .map((doc) => doc.name.split('/').pop())
  .filter((uid) => !uid.startsWith('demo-'));
if (mine.length !== 1) {
  throw new Error(`Expected one signed-in profile, found ${mine.length}`);
}
const uid = mine[0];

// Tomorrow, in the phone's own days; its ISO week, as rsvp.iso_week names it.
const now = new Date();
const tomorrow = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
const days = ['sun', 'mon', 'tue', 'wed', 'thu', 'fri', 'sat'];
const pad = (n) => String(n).padStart(2, '0');
const date = `${tomorrow.getFullYear()}-${pad(tomorrow.getMonth() + 1)}-${pad(tomorrow.getDate())}`;
const thursday = new Date(tomorrow);
thursday.setDate(tomorrow.getDate() + 3 - ((tomorrow.getDay() + 6) % 7));
const firstThursday = new Date(thursday.getFullYear(), 0, 4);
const weekNumber =
  1 + Math.round(((thursday - firstThursday) / 86400000 - 3 + ((firstThursday.getDay() + 6) % 7)) / 7);
const week = `${thursday.getFullYear()}-W${pad(weekNumber)}`;
const longAgo = new Date(now.getTime() - 30 * 86400000);

write(`rondas/${RONDA}`, {
  seatId: `solymar-norte_mate_${days[tomorrow.getDay()]}-afternoon`,
  pretext: 'mate',
  barrio: 'solymar-norte',
  slot: { day: days[tomorrow.getDay()], time: 'afternoon', hour: '16:00' },
  size: 2,
  status: 'active',
  place: { name: 'frente al quiosco (demo)', landmark: 'al lado de la parada' },
  hosts: { anfitrion: JORGE, anfitrionName: 'Jorge' },
  createdAt: longAgo,
});
write(`rondas/${RONDA}/members/${JORGE}`, { brings: ['termo'], state: 'active', joinedAt: longAgo });
write(`users/${JORGE}`, { firstName: 'Jorge', ageBand: '60-69' });
write(`rondas/${RONDA}/members/${uid}`, { brings: ['pan'], state: 'active', joinedAt: now });
write(`users/${uid}/rondas/${RONDA}`, { joinedAt: now });
write(`rondas/${RONDA}/views/week`, {
  week,
  date,
  going: [],
  noCount: 0,
  unansweredCount: 2,
  updatedAt: now,
});
write(`rondas/${RONDA}/welcomes/${uid}`, {
  week,
  date,
  hour: '16:00',
  newcomerName: 'Marta',
  choices: [{ uid: JORGE, firstName: 'Jorge' }],
  status: 'open',
  declined: [],
  createdAt: now,
  updatedAt: now,
});
output.newcomerUid = uid;
