import { computeMatch } from './compute-match';

describe('computeMatch', () => {
  const pantry = new Set(['huevos', 'tomate', 'aceite', 'cebolla', 'sal', 'pan', 'ajo']);

  it('returns 100% when every required ingredient is in the pantry', () => {
    const result = computeMatch(
      [
        { ingredientId: 'pan', optional: false },
        { ingredientId: 'tomate', optional: false },
        { ingredientId: 'aceite', optional: false },
        { ingredientId: 'ajo', optional: false },
      ],
      pantry,
    );
    expect(result.matchPct).toBe(100);
    expect(result.missingIngredientIds).toEqual([]);
  });

  it('ignores optional ingredients when scoring', () => {
    const result = computeMatch(
      [
        { ingredientId: 'huevos', optional: false },
        { ingredientId: 'sal', optional: false },
        { ingredientId: 'pimenton', optional: true },
      ],
      pantry,
    );
    expect(result.matchPct).toBe(100);
    expect(result.missingIngredientIds).toEqual([]);
  });

  it('reports missing required ingredients and a partial percentage', () => {
    const result = computeMatch(
      [
        { ingredientId: 'tomate', optional: false },
        { ingredientId: 'pepino', optional: false },
        { ingredientId: 'pimiento', optional: false },
        { ingredientId: 'ajo', optional: false },
        { ingredientId: 'aceite', optional: false },
      ],
      pantry,
    );
    expect(result.matchPct).toBe(60);
    expect(result.missingIngredientIds.sort()).toEqual(['pepino', 'pimiento'].sort());
  });

  it('returns 100% when a recipe has no required ingredients', () => {
    const result = computeMatch([{ ingredientId: 'perejil', optional: true }], pantry);
    expect(result.matchPct).toBe(100);
  });
});
