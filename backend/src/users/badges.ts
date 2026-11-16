import { DataSource } from 'typeorm';

export const BADGE_CATALOG = [
  { code: 'primera-cocina', name: 'Primera cocina', hint: 'Cocina una receta' },
  { code: 'racha-3', name: 'Tres días', hint: 'Cocina 3 días seguidos' },
  { code: 'racha-7', name: 'Una semana', hint: 'Cocina 7 días seguidos' },
  {
    code: 'cero-desperdicio',
    name: 'Cero desperdicio',
    hint: 'Cocina una receta con lo que ya tienes',
  },
  { code: 'tu-receta', name: 'Tu receta', hint: 'Publica una receta' },
  { code: 'despensa', name: 'Despensa', hint: 'Guarda 8 ingredientes en casa' },
] as const;

/** Las que salen de contadores. Cero desperdicio se apunta al cocinar. */
export function earnedFromActivity(input: {
  cookedCount: number;
  bestStreak: number;
  recipesCount: number;
  pantryCount: number;
}) {
  const codes: string[] = [];
  if (input.cookedCount >= 1) codes.push('primera-cocina');
  if (input.bestStreak >= 3) codes.push('racha-3');
  if (input.bestStreak >= 7) codes.push('racha-7');
  if (input.recipesCount >= 1) codes.push('tu-receta');
  if (input.pantryCount >= 8) codes.push('despensa');
  return codes;
}

export async function awardBadges(
  db: DataSource,
  userId: string,
  codes: string[],
) {
  const unique = [...new Set(codes)];
  if (!unique.length) return;
  await db.query(
    `INSERT INTO user_badges (id, "userId", code)
     SELECT uuid_generate_v4(), $1, x
     FROM unnest($2::text[]) AS x
     ON CONFLICT ("userId", code) DO NOTHING`,
    [userId, unique],
  );
}
