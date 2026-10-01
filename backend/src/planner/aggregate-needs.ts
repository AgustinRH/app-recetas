import { normalizeUnit, PantryStock, toBase } from '../recipes/compute-match';

export type NeedInput = {
  ingredientId: string;
  name: string;
  quantity: number;
  unit: string;
  optional?: boolean;
};

export type Gap = {
  ingredientId: string;
  name: string;
  quantity: number;
  unit: string;
};

type Family = 'mass' | 'volume' | 'count';

type Bucket =
  | { kind: 'base'; family: Family; amount: number; name: string }
  | { kind: 'loose'; unit: string; amount: number; name: string };

const EPS = 1e-6;

function singular(unit: string) {
  const u = normalizeUnit(unit);
  return u.endsWith('s') && u.length > 3 ? u.slice(0, -1) : u;
}

function roundShopping(amount: number) {
  if (!(amount > 0)) return 0;
  if (amount >= 100) return Math.ceil(amount - 1e-9);
  const rounded = Math.round(amount * 10) / 10;
  if (rounded > 0) return rounded;
  return Math.ceil(amount * 10) / 10;
}

function displayFromBase(amount: number, family: Family) {
  if (family === 'mass') {
    if (amount >= 1000) return { quantity: roundShopping(amount / 1000), unit: 'kg' };
    return { quantity: roundShopping(amount), unit: 'g' };
  }
  if (family === 'volume') {
    if (amount >= 1000) return { quantity: roundShopping(amount / 1000), unit: 'l' };
    return { quantity: roundShopping(amount), unit: 'ml' };
  }
  return { quantity: roundShopping(amount), unit: 'ud' };
}

/**
 * Suma lo que piden todas las recetas del plan y resta la despensa una sola
 * vez. Los opcionales no entran. Unidades de la misma familia (g/kg, ml/l) se
 * convierten. Si la despensa está en una unidad incompatible, no se penaliza,
 * igual que el matching de una receta suelta.
 */
export function gapsForPlan(lines: NeedInput[], stock: Map<string, PantryStock>): Gap[] {
  const buckets = new Map<string, Bucket>();
  for (const line of lines) {
    if (line.optional) continue;
    const qty = Number(line.quantity) || 0;
    if (!(qty > 0)) continue;
    const base = toBase(qty, line.unit);
    const current = buckets.get(line.ingredientId);
    if (!current) {
      buckets.set(
        line.ingredientId,
        base
          ? { kind: 'base', family: base.family, amount: base.amount, name: line.name }
          : { kind: 'loose', unit: singular(line.unit), amount: qty, name: line.name },
      );
      continue;
    }
    if (current.kind === 'base' && base && base.family === current.family) {
      current.amount += base.amount;
      continue;
    }
    if (current.kind === 'loose' && !base && singular(line.unit) === current.unit) {
      current.amount += qty;
    }
  }

  const gaps: Gap[] = [];
  for (const [ingredientId, bucket] of buckets) {
    const have = stock.get(ingredientId);
    if (bucket.kind === 'base') {
      let haveAmount = 0;
      if (have && have.quantity > 0) {
        const converted = toBase(have.quantity, have.unit);
        if (!converted || converted.family !== bucket.family) continue;
        haveAmount = converted.amount;
      }
      const deficit = bucket.amount - haveAmount;
      if (deficit <= EPS) continue;
      const shown = displayFromBase(deficit, bucket.family);
      if (shown.quantity <= 0) continue;
      gaps.push({ ingredientId, name: bucket.name, ...shown });
      continue;
    }

    if (have && have.quantity > 0) {
      if (toBase(have.quantity, have.unit)) continue;
      if (singular(have.unit) !== bucket.unit) continue;
      const deficit = bucket.amount - have.quantity;
      if (deficit <= EPS) continue;
      const quantity = roundShopping(deficit);
      if (quantity <= 0) continue;
      gaps.push({ ingredientId, name: bucket.name, quantity, unit: bucket.unit });
      continue;
    }
    const quantity = roundShopping(bucket.amount);
    if (quantity <= 0) continue;
    gaps.push({ ingredientId, name: bucket.name, quantity, unit: bucket.unit });
  }

  gaps.sort((a, b) => a.name.localeCompare(b.name, 'es'));
  return gaps;
}
