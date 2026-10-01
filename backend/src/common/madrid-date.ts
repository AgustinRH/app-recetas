/** Fecha de calendario en España, YYYY-MM-DD. El día no cambia a las 02:00. */
export function todayInMadrid(now = new Date()) {
  return new Intl.DateTimeFormat('en-CA', {
    timeZone: 'Europe/Madrid',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
  }).format(now);
}

/** Suma días a una fecha YYYY-MM-DD sin depender de la zona del servidor. */
export function shiftIsoDate(iso: string, days: number) {
  const [year, month, day] = iso.split('-').map(Number);
  const date = new Date(Date.UTC(year, month - 1, day + days));
  return date.toISOString().slice(0, 10);
}

/**
 * Días seguidos cocinando. Cuenta hasta hoy, o hasta ayer si hoy todavía
 * no has cocinado. Un hueco de más de un día la deja en cero.
 */
export function cookingStreak(days: string[], today: string) {
  const unique = [...new Set(days)].sort();
  let best = 0;
  let run = 0;
  let previous = '';
  for (const day of unique) {
    run = previous && shiftIsoDate(previous, 1) === day ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }

  const cooked = new Set(unique);
  let cursor = cooked.has(today)
    ? today
    : cooked.has(shiftIsoDate(today, -1))
      ? shiftIsoDate(today, -1)
      : '';
  let streak = 0;
  while (cursor && cooked.has(cursor)) {
    streak += 1;
    cursor = shiftIsoDate(cursor, -1);
  }
  return { streak, bestStreak: best };
}
