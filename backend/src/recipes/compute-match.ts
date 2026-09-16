export type MatchInput = { ingredientId: string; optional: boolean };

export function computeMatch(
  ingredients: MatchInput[],
  pantryIds: Set<string>,
): { matchPct: number; missingIngredientIds: string[] } {
  const required = ingredients.filter((i) => !i.optional);
  if (required.length === 0) {
    return { matchPct: 100, missingIngredientIds: [] };
  }
  const missingIngredientIds = required
    .filter((i) => !pantryIds.has(i.ingredientId))
    .map((i) => i.ingredientId);
  const covered = required.length - missingIngredientIds.length;
  const matchPct = Math.round((1000 * covered) / required.length) / 10;
  return { matchPct, missingIngredientIds };
}
