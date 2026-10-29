// Cerca tuyo: one barrio's counts at a time, read straight from
// `cerca/{barrio}`, which firestore.rules lets anyone get. The refresh_cerca
// function writes them (functions/cerca_tuyo.py); nothing here writes.
import {
  BARRIOS,
  element,
  rondaItem,
  t,
  translatePage,
  updatedText,
  waitingItem,
} from './ronda.js';

// The Firestore emulator's port in firebase.json, for a page served by the
// Hosting emulator on this machine.
const EMULATOR_FIRESTORE_PORT = 8088;
const LOCAL_HOSTS = ['127.0.0.1', 'localhost'];
const STORED_BARRIO = 'ronda-cerca-barrio';

translatePage();

const picker = document.getElementById('barrio');
const results = document.getElementById('results');
const config = loadConfig();
config.catch(() => {}); // reported when a barrio is shown

picker.addEventListener('change', () => {
  remember(picker.value);
  show(picker.value);
});

const first = new URLSearchParams(location.search).get('barrio') || recalled();
if (first && first in BARRIOS) {
  picker.value = first;
  show(first);
}

// The project and its public web key come from Hosting's reserved
// /__/firebase/init.json; the page itself names neither.
async function loadConfig() {
  const response = await fetch('/__/firebase/init.json');
  if (!response.ok) throw new Error(`init.json ${response.status}`);
  return response.json();
}

async function show(barrio) {
  if (!barrio) {
    results.replaceChildren();
    return;
  }
  results.replaceChildren(element('p', 'status', t('loading')));
  try {
    const counts = await readCounts(barrio);
    if (picker.value === barrio) render(barrio, counts);
  } catch (error) {
    console.error(error);
    if (picker.value === barrio) results.replaceChildren(element('p', 'status', t('error')));
  }
}

async function readCounts(barrio) {
  const { projectId, apiKey } = await config;
  const local = LOCAL_HOSTS.includes(location.hostname);
  const origin = local
    ? `http://${location.hostname}:${EMULATOR_FIRESTORE_PORT}`
    : 'https://firestore.googleapis.com';
  const path = `/v1/projects/${projectId}/databases/(default)/documents/cerca/${encodeURIComponent(barrio)}`;
  const query = apiKey && !local ? `?key=${encodeURIComponent(apiKey)}` : '';
  const response = await fetch(origin + path + query);
  if (response.status === 404) return { rondas: [], waiting: [], updatedAt: null };
  if (!response.ok) throw new Error(`cerca/${barrio} ${response.status}`);
  return decodeFields((await response.json()).fields || {});
}

function render(barrio, counts) {
  const name = BARRIOS[barrio];
  const parts = [];
  if (counts.rondas.length) {
    parts.push(element('h2', null, t('rondasIn', { barrio: name })));
    const list = element('ul', 'seats');
    list.append(...counts.rondas.map((row) => rondaItem(row)));
    parts.push(list);
  } else {
    parts.push(element('p', 'status', t('noRondasIn', { barrio: name })));
  }
  if (counts.waiting.length) {
    parts.push(element('h2', null, t('waitingTitle')));
    const list = element('ul', 'waitings');
    list.append(...counts.waiting.map((count) => waitingItem(count, barrio)));
    parts.push(list);
  }
  const updated = updatedText(counts.updatedAt);
  if (updated) parts.push(element('p', 'note', updated));
  results.replaceChildren(...parts);
}

// Firestore's REST documents carry typed values ({"integerValue": "4"}); this
// turns them back into plain JSON.
function decodeFields(fields) {
  return Object.fromEntries(Object.entries(fields).map(([key, value]) => [key, decode(value)]));
}

function decode(value) {
  if ('mapValue' in value) return decodeFields(value.mapValue.fields || {});
  if ('arrayValue' in value) return (value.arrayValue.values || []).map(decode);
  if ('integerValue' in value) return Number(value.integerValue);
  if ('nullValue' in value) return null;
  const [kind] = Object.keys(value);
  return value[kind];
}

function remember(barrio) {
  const url = new URL(location.href);
  if (barrio) url.searchParams.set('barrio', barrio);
  else url.searchParams.delete('barrio');
  history.replaceState(null, '', url);
  try {
    localStorage.setItem(STORED_BARRIO, barrio);
  } catch {
    // Private windows may refuse storage; the address keeps the barrio anyway.
  }
}

function recalled() {
  try {
    return localStorage.getItem(STORED_BARRIO);
  } catch {
    return null;
  }
}
