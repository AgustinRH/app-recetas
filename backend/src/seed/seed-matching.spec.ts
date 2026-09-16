import { computeMatch } from '../recipes/compute-match';
import { DEMO_PANTRY_NAMES, RECIPE_SEEDS } from './seed-data';

describe('seed matching (qué puedo cocinar)', () => {
  const pantry = new Set(DEMO_PANTRY_NAMES);

  const scored = RECIPE_SEEDS.map((recipe) => {
    const { matchPct, missingIngredientIds } = computeMatch(
      recipe.ingredients.map((i) => ({
        ingredientId: i.name,
        optional: Boolean(i.optional),
      })),
      pantry,
    );
    return { title: recipe.title, matchPct, missing: missingIngredientIds };
  }).sort((a, b) => b.matchPct - a.matchPct);

  it('ranks Pan con tomate first with a full match', () => {
    expect(scored[0].title).toBe('Pan con tomate');
    expect(scored[0].matchPct).toBe(100);
  });

  it('places Tortilla de patatas high with only patata missing', () => {
    const tortilla = scored.find((s) => s.title === 'Tortilla de patatas');
    expect(tortilla).toBeDefined();
    expect(tortilla!.matchPct).toBe(80);
    expect(tortilla!.missing).toEqual(['Patata']);
  });

  it('lists pepino and pimiento as missing for gazpacho', () => {
    const gazpacho = scored.find((s) => s.title === 'Gazpacho');
    expect(gazpacho!.missing.sort()).toEqual(['Pepino', 'Pimiento'].sort());
    expect(gazpacho!.matchPct).toBe(66.7);
  });
});
