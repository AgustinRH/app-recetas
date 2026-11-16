import { computeMatch } from './compute-match';

describe('computeMatch', () => {
  const pantry = new Set([
    'huevos',
    'tomate',
    'aceite',
    'cebolla',
    'sal',
    'pan',
    'ajo',
  ]);

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
    expect(result.missingIngredientIds.sort()).toEqual(
      ['pepino', 'pimiento'].sort(),
    );
  });

  it('returns 100% when a recipe has no required ingredients', () => {
    const result = computeMatch(
      [{ ingredientId: 'perejil', optional: true }],
      pantry,
    );
    expect(result.matchPct).toBe(100);
  });

  describe('con cantidades (Map de despensa)', () => {
    const stock = new Map([
      ['huevos', { quantity: 4, unit: 'ud' }],
      ['harina', { quantity: 1, unit: 'kg' }],
      ['leche', { quantity: 50, unit: 'cl' }],
      ['ajo', { quantity: 1, unit: 'ud' }],
      ['sal', { quantity: 0, unit: 'g' }],
    ]);

    it('cuenta como falta un ingrediente del que no hay suficiente', () => {
      const result = computeMatch(
        [
          { ingredientId: 'huevos', optional: false, quantity: 6, unit: 'ud' },
          { ingredientId: 'harina', optional: false, quantity: 200, unit: 'g' },
        ],
        stock,
      );
      expect(result.matchPct).toBe(50);
      expect(result.missingIngredientIds).toEqual(['huevos']);
      expect(result.insufficientIngredientIds).toEqual(['huevos']);
    });

    it('acepta cantidad igual a la necesaria', () => {
      const result = computeMatch(
        [{ ingredientId: 'huevos', optional: false, quantity: 4, unit: 'ud' }],
        stock,
      );
      expect(result.matchPct).toBe(100);
    });

    it('convierte entre unidades de la misma familia (kg→g, cl→ml)', () => {
      const result = computeMatch(
        [
          { ingredientId: 'harina', optional: false, quantity: 900, unit: 'g' },
          { ingredientId: 'leche', optional: false, quantity: 400, unit: 'ml' },
        ],
        stock,
      );
      expect(result.matchPct).toBe(100);
      const tooMuch = computeMatch(
        [{ ingredientId: 'leche', optional: false, quantity: 600, unit: 'ml' }],
        stock,
      );
      expect(tooMuch.insufficientIngredientIds).toEqual(['leche']);
    });

    it('no penaliza unidades incompatibles (1 ud de ajo frente a 2 dientes)', () => {
      const result = computeMatch(
        [
          {
            ingredientId: 'ajo',
            optional: false,
            quantity: 2,
            unit: 'dientes',
          },
        ],
        stock,
      );
      expect(result.matchPct).toBe(100);
    });

    it('cantidad 0 en la despensa cuenta como que se ha acabado', () => {
      const result = computeMatch(
        [{ ingredientId: 'sal', optional: false, quantity: 1, unit: 'cdita' }],
        stock,
      );
      expect(result.missingIngredientIds).toEqual(['sal']);
      expect(result.insufficientIngredientIds).toEqual(['sal']);
    });

    it('un ingrediente ausente no aparece como insuficiente', () => {
      const result = computeMatch(
        [{ ingredientId: 'tomate', optional: false, quantity: 2, unit: 'ud' }],
        stock,
      );
      expect(result.missingIngredientIds).toEqual(['tomate']);
      expect(result.insufficientIngredientIds).toEqual([]);
    });
  });
});
