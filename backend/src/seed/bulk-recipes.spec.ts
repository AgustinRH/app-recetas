import { readFileSync } from 'fs';
import { join } from 'path';
import { INGREDIENT_SEEDS } from './seed-data';

type Bulk = {
  title: string;
  steps: string[];
  ingredients: { name: string; quantity: number; unit: string }[];
  dietTags: string[];
  photoQuery: string;
  servings: number;
  calories: number;
};

const recipes = JSON.parse(
  readFileSync(join(__dirname, 'bulk-recipes.json'), 'utf8'),
) as Bulk[];

const names = new Set(INGREDIENT_SEEDS.map((i) => i.name));
const allowedTags = new Set(['vegana', 'vegetariana', 'sin gluten', 'keto']);

describe('bulk recipe catalog', () => {
  it('has hundreds of unique titles that only use catalog ingredients', () => {
    expect(recipes.length).toBeGreaterThanOrEqual(500);
    expect(new Set(recipes.map((r) => r.title)).size).toBe(recipes.length);
    for (const recipe of recipes) {
      expect(recipe.steps.length).toBeGreaterThanOrEqual(2);
      expect(recipe.ingredients.length).toBeGreaterThanOrEqual(2);
      expect(recipe.photoQuery.length).toBeGreaterThan(3);
      expect(recipe.servings).toBeGreaterThan(0);
      expect(recipe.calories).toBeGreaterThan(0);
      for (const tag of recipe.dietTags)
        expect(allowedTags.has(tag)).toBe(true);
      for (const item of recipe.ingredients)
        expect(names.has(item.name)).toBe(true);
    }
  });
});
