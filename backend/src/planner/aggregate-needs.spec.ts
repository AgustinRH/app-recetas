import { gapsForPlan } from './aggregate-needs';

describe('gapsForPlan', () => {
  const arroz = { ingredientId: 'arroz', name: 'Arroz', optional: false };

  it('sums the same ingredient across recipes and subtracts the pantry once', () => {
    const gaps = gapsForPlan(
      [
        { ...arroz, quantity: 200, unit: 'g' },
        { ...arroz, quantity: 0.3, unit: 'kg' },
      ],
      new Map([['arroz', { quantity: 120, unit: 'g' }]]),
    );
    expect(gaps).toEqual([
      { ingredientId: 'arroz', name: 'Arroz', quantity: 380, unit: 'g' },
    ]);
  });

  it('omits an ingredient the pantry already covers', () => {
    const gaps = gapsForPlan(
      [{ ...arroz, quantity: 200, unit: 'g' }],
      new Map([['arroz', { quantity: 500, unit: 'g' }]]),
    );
    expect(gaps).toEqual([]);
  });

  it('ignores optional ingredients', () => {
    const gaps = gapsForPlan(
      [
        {
          ingredientId: 'perejil',
          name: 'Perejil',
          quantity: 1,
          unit: 'manojo',
          optional: true,
        },
      ],
      new Map(),
    );
    expect(gaps).toEqual([]);
  });

  it('does not flag a pantry unit that cannot be compared', () => {
    const gaps = gapsForPlan(
      [
        {
          ingredientId: 'ajo',
          name: 'Ajo',
          quantity: 2,
          unit: 'diente',
          optional: false,
        },
      ],
      new Map([['ajo', { quantity: 1, unit: 'ud' }]]),
    );
    expect(gaps).toEqual([]);
  });

  it('sums loose units and subtracts the same unit in the pantry', () => {
    const gaps = gapsForPlan(
      [
        {
          ingredientId: 'ajo',
          name: 'Ajo',
          quantity: 2,
          unit: 'diente',
          optional: false,
        },
        {
          ingredientId: 'ajo',
          name: 'Ajo',
          quantity: 3,
          unit: 'dientes',
          optional: false,
        },
      ],
      new Map([['ajo', { quantity: 1, unit: 'diente' }]]),
    );
    expect(gaps).toEqual([
      { ingredientId: 'ajo', name: 'Ajo', quantity: 4, unit: 'diente' },
    ]);
  });
});
