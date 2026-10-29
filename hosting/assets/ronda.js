// Shared by Cerca tuyo (/) and the tear-off flyer's page (/f/{id}): the copy in
// es-419 and English, the barrio names, and how a row of counts reads. Plain
// browser JavaScript, no build step and no Firebase SDK: these pages must load
// fast on old phones (docs/DESIGN.md § Tooling and scope).

export const BARRIOS = {
  'shangrila': 'Shangrilá',
  'san-jose-de-carrasco': 'San José de Carrasco',
  'lagomar-sur': 'Lagomar Sur',
  'lagomar-norte': 'Lagomar Norte',
  'solymar-sur': 'Solymar Sur',
  'solymar-norte': 'Solymar Norte',
  'lomas-de-solymar': 'Lomas de Solymar',
  'el-pinar-sur': 'El Pinar Sur',
  'el-pinar-norte': 'El Pinar Norte',
};

const STRINGS = {
  es: {
    cercaTitle: 'Cerca tuyo',
    cercaLead:
      'Grupos de 5 o 6 vecinos que se juntan una vez por semana, siempre en lugares públicos.',
    barrioLabel: '¿En qué barrio estás?',
    barrioPick: 'Elegí tu barrio',
    loading: 'Cargando…',
    error: 'No pudimos cargar los grupos. Probá de nuevo en un rato.',
    rondasIn: 'Rondas en {barrio}',
    noRondasIn: 'Todavía no hay rondas en {barrio}.',
    waitingTitle: 'Esperando que arranque',
    waitingOne: '1 vecino espera que arranque {pretext} en {barrio}.',
    waitingMany: '{count} vecinos esperan que arranque {pretext} en {barrio}.',
    leftOne: 'Queda 1',
    leftMany: 'Quedan {count}',
    ofCap: '{members} de {cap}',
    full: 'Lleno',
    waitingList: '{count} en lista de espera',
    ageRange: 'De {from} a {to} años',
    ageFrom: 'De {from} años para arriba',
    slot: '{days}, {band}',
    noNames: 'No mostramos nombres ni lugares exactos.',
    exactPlace: 'El lugar exacto te lo mostramos el día antes, cuando confirmás.',
    join: 'Quiero sumarme',
    joinNote: 'Funciona en el navegador; no hace falta bajar nada.',
    updated: 'Actualizado: {when}.',
    landingTitle: 'Cerca de este volante',
    landingLead:
      'Rondas a pocas cuadras de acá: grupos de 5 o 6 vecinos que se juntan una vez por semana, siempre en lugares públicos.',
    noRondasHere: 'Todavía no hay rondas a pocas cuadras de acá.',
    notFound: 'No encontramos este volante.',
    allBarrios: 'Ver todos los barrios',
    lastBusFrom: 'Último ómnibus desde {stop}',
    lastBus: 'Último ómnibus',
    weekday: 'De lunes a viernes',
    saturday: 'Sábados',
    sunday: 'Domingos',
    noBus: 'No pasa',
    about: '{time}, aprox.',
    line: 'Línea {route}.',
    publishedAt: 'Horario publicado: {time} en {stop}.',
    published: 'Horario publicado.',
    busSource:
      'Según el horario publicado por la Dirección Nacional de Transporte, que puede cambiar.',
    pretexts: {
      mate: ['Mate en la rambla', 'un mate en la rambla'],
      truco: ['Truco', 'un truco'],
      futbol5: ['Fútbol 5', 'un fútbol 5'],
      caminata: ['Caminata', 'una caminata'],
    },
    days: {
      mon: 'Los lunes', tue: 'Los martes', wed: 'Los miércoles', thu: 'Los jueves',
      fri: 'Los viernes', sat: 'Los sábados', sun: 'Los domingos',
    },
    bands: { morning: 'de 9 a 12', afternoon: 'de 14 a 18', evening: 'de 19 a 21' },
    locale: 'es-UY',
  },
  en: {
    cercaTitle: 'Near you',
    cercaLead: 'Groups of 5 or 6 neighbours who meet once a week, always in public places.',
    barrioLabel: 'Which barrio are you in?',
    barrioPick: 'Pick your barrio',
    loading: 'Loading…',
    error: "We couldn't load the groups. Try again in a while.",
    rondasIn: 'Rondas in {barrio}',
    noRondasIn: 'No rondas in {barrio} yet.',
    waitingTitle: 'Waiting to start',
    waitingOne: '1 neighbour is waiting for {pretext} to start in {barrio}.',
    waitingMany: '{count} neighbours are waiting for {pretext} to start in {barrio}.',
    leftOne: '1 place left',
    leftMany: '{count} places left',
    ofCap: '{members} of {cap}',
    full: 'Full',
    waitingList: '{count} on the waiting list',
    ageRange: 'Ages {from} to {to}',
    ageFrom: 'Ages {from} and up',
    slot: '{days}, {band}',
    noNames: "We don't show names or exact places.",
    exactPlace: 'We show you the exact place the day before, when you confirm.',
    join: 'I want to join',
    joinNote: 'Works in the browser; nothing to download.',
    updated: 'Updated: {when}.',
    landingTitle: 'Near this flyer',
    landingLead:
      'Rondas a few blocks from here: groups of 5 or 6 neighbours who meet once a week, always in public places.',
    noRondasHere: 'No rondas a few blocks from here yet.',
    notFound: "We couldn't find this flyer.",
    allBarrios: 'See every barrio',
    lastBusFrom: 'Last bus from {stop}',
    lastBus: 'Last bus',
    weekday: 'Monday to Friday',
    saturday: 'Saturdays',
    sunday: 'Sundays',
    noBus: 'No bus',
    about: 'about {time}',
    line: 'Line {route}.',
    publishedAt: 'Published timetable: {time} at {stop}.',
    published: 'Published timetable.',
    busSource: "From the timetable Uruguay's national transport office publishes; it may change.",
    pretexts: {
      mate: ['Mate on the rambla', 'a mate on the rambla'],
      truco: ['Truco', 'a truco game'],
      futbol5: ['Five-a-side football', 'a five-a-side game'],
      caminata: ['A walk', 'a walk'],
    },
    days: {
      mon: 'Mondays', tue: 'Tuesdays', wed: 'Wednesdays', thu: 'Thursdays',
      fri: 'Fridays', sat: 'Saturdays', sun: 'Sundays',
    },
    bands: { morning: '9 to 12', afternoon: '2 to 6 pm', evening: '7 to 9 pm' },
    locale: 'en',
  },
};

// es-419 unless ?lang=en, or the browser prefers English over Spanish.
const LANG = (() => {
  const asked = new URLSearchParams(location.search).get('lang');
  if (asked === 'es' || asked === 'en') return asked;
  for (const tag of navigator.languages || [navigator.language || '']) {
    const base = tag.toLowerCase().slice(0, 2);
    if (base === 'es' || base === 'en') return base;
  }
  return 'es';
})();
const COPY = STRINGS[LANG];

export function t(key, values = {}) {
  return COPY[key].replace(/\{(\w+)\}/g, (_, name) => String(values[name]));
}

// Puts the page in the reader's language: every element with data-t="key".
export function translatePage() {
  document.documentElement.lang = LANG === 'es' ? 'es-419' : 'en';
  for (const element of document.querySelectorAll('[data-t]')) {
    element.textContent = t(element.dataset.t);
  }
}

export function element(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function pretextName(pretext) {
  return (COPY.pretexts[pretext] || [pretext])[0];
}

function pretextWithArticle(pretext) {
  return (COPY.pretexts[pretext] || [pretext, pretext])[1];
}

export function slotText(slot) {
  const [day, band] = slot.split('-');
  return t('slot', { days: COPY.days[day] || day, band: COPY.bands[band] || band });
}

function ageText(row) {
  if (row.ageFrom == null) return null;
  return row.ageTo == null
    ? t('ageFrom', { from: row.ageFrom })
    : t('ageRange', { from: row.ageFrom, to: row.ageTo });
}

// One ronda: activity, day and band, age range, and its places: "Quedan 2"
// over "4 de 6", or "Lleno" over its waiting list. `barrio` adds the barrio's
// name, for the flyer page, which shows more than one.
export function rondaItem(row, { barrio = false } = {}) {
  const item = element('li', 'seat');
  const main = element('div', 'seat-main');
  main.append(element('p', 'seat-title', pretextName(row.pretext)));
  const details = [slotText(row.slot), ageText(row)].filter(Boolean).join(' · ');
  main.append(element('p', 'seat-meta', details));
  if (barrio) main.append(element('p', 'seat-meta', BARRIOS[row.barrio] || row.barrio));

  const left = Math.max(row.cap - row.members, 0);
  const places = element('div', left ? 'seat-places' : 'seat-places is-full');
  if (left) {
    places.append(element('p', 'seat-left', left === 1 ? t('leftOne') : t('leftMany', { count: left })));
    places.append(element('p', 'seat-count', t('ofCap', { members: row.members, cap: row.cap })));
  } else {
    places.append(element('p', 'seat-left', t('full')));
    places.append(
      element(
        'p',
        'seat-count',
        row.waiting ? t('waitingList', { count: row.waiting }) : t('ofCap', { members: row.members, cap: row.cap }),
      ),
    );
  }
  item.append(main, places);
  return item;
}

// "9 vecinos esperan que arranque una caminata en El Pinar Sur."
export function waitingItem(count, barrio) {
  const values = {
    count: count.count,
    pretext: pretextWithArticle(count.pretext),
    barrio: BARRIOS[barrio] || barrio,
  };
  return element('li', 'waiting', t(count.count === 1 ? 'waitingOne' : 'waitingMany', values));
}

export function updatedText(isoTime) {
  if (!isoTime) return null;
  const when = new Intl.DateTimeFormat(COPY.locale, {
    weekday: 'long',
    hour: 'numeric',
    minute: '2-digit',
    hour12: LANG === 'en',
    timeZone: 'America/Montevideo',
  }).format(new Date(isoTime));
  return t('updated', { when });
}
