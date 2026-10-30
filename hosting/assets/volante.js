// The flyers' page, /f/{id}: the rondas a few blocks from where the flyer
// hangs and, for a tear-off, that stop's last bus, from the flyer_landing
// function at /api/f/{id} (firebase.json). An "Un mate de más" flyer
// (kind "mate") gets its own title and intro. The first load in a tab counts one scan (POST);
// a reload in the same tab only reads (GET), so refreshing doesn't inflate it.
// Link previews fetch the HTML and run no script, so they count nothing.
import {
  element,
  rondaItem,
  t,
  translatePage,
  updatedText,
  waitingItem,
} from './ronda.js';

const DAY_TYPES = ['weekday', 'saturday', 'sunday'];

translatePage();

const results = document.getElementById('results');
const bus = document.getElementById('bus');
const flyerId = location.pathname.split('/').filter(Boolean)[1] || '';

load();

async function load() {
  if (!/^[a-z0-9]{8}$/.test(flyerId)) {
    notFound();
    return;
  }
  // Marked before the request goes: a reload while a cold function is still
  // answering would otherwise count the same scan twice. A failure unmarks it.
  const counted = `ronda-scan-${flyerId}`;
  const method = alreadyCounted(counted) ? 'GET' : 'POST';
  if (method === 'POST') setCounted(counted, true);
  try {
    const response = await fetch(`/api/f/${flyerId}`, { method, cache: 'no-store' });
    if (response.status === 404) {
      notFound();
      return;
    }
    if (!response.ok) throw new Error(`/api/f ${response.status}`);
    render(await response.json());
  } catch (error) {
    console.error(error);
    if (method === 'POST') setCounted(counted, false);
    results.replaceChildren(element('p', 'status', t('error')));
  }
}

function render(page) {
  if (page.kind === 'mate') renderMateHeading();
  const parts = [];
  if (page.rondas.length) {
    const list = element('ul', 'seats');
    list.append(...page.rondas.map((row) => rondaItem(row, { barrio: true })));
    parts.push(list);
  } else {
    parts.push(element('p', 'status', t('noRondasHere')));
  }
  if (page.waiting.length) {
    parts.push(element('h2', null, t('waitingTitle')));
    const list = element('ul', 'waitings');
    list.append(...page.waiting.map((count) => waitingItem(count, count.barrio)));
    parts.push(list);
  }
  const updated = updatedText(page.updatedAt);
  if (updated) parts.push(element('p', 'note', updated));
  results.replaceChildren(...parts);
  renderBus(page.lastBus);
}

// The tear-off's heading is the page's own; a mate flyer's names the seat its
// ronda keeps for someone new (docs/PRODUCT.md § Flyers).
function renderMateHeading() {
  const title = t('mateLandingTitle');
  document.querySelector('h1').textContent = title;
  document.querySelector('.lead').textContent = t('mateLandingLead');
  document.title = `${title} · Ronda`;
}

// "Último ómnibus desde {stop}": each day type's time, marked approximate
// where the timetable has no time at this stop, with the published time it
// comes from. Stays hidden when no day has a bus, as on every mate flyer.
function renderBus(lastBus) {
  if (!lastBus || !DAY_TYPES.some((dayType) => lastBus[dayType])) return;
  const title = lastBus.stop ? t('lastBusFrom', { stop: lastBus.stop }) : t('lastBus');
  const list = element('dl', 'bus-times');
  for (const dayType of DAY_TYPES) {
    const entry = lastBus[dayType];
    const value = element('dd');
    if (entry) {
      value.append(
        element('span', 'bus-time', entry.estimated ? t('about', { time: entry.time }) : entry.time),
        element('span', 'bus-detail', ` ${t('line', { route: entry.route })} `),
        element(
          'span',
          'bus-detail',
          entry.estimated && entry.published
            ? t('publishedAt', { time: entry.published.time, stop: entry.published.stop })
            : t('published'),
        ),
      );
    } else {
      value.append(element('span', 'bus-time', t('noBus')));
    }
    list.append(element('dt', null, t(dayType)), value);
  }
  bus.replaceChildren(element('h2', null, title), list, element('p', 'note', t('busSource')));
  bus.hidden = false;
}

function notFound() {
  document.querySelector('h1').textContent = t('notFound');
  document.querySelector('.lead').hidden = true;
  results.replaceChildren();
}

function alreadyCounted(key) {
  try {
    return sessionStorage.getItem(key) === '1';
  } catch {
    return false;
  }
}

function setCounted(key, counted) {
  try {
    if (counted) sessionStorage.setItem(key, '1');
    else sessionStorage.removeItem(key);
  } catch {
    // Without storage a reload counts again; the count stays per flyer.
  }
}
