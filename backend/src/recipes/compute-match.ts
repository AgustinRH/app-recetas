export type MatchInput = {
  ingredientId: string;
  optional: boolean;
  /** Cantidad que pide la receta. Si falta, solo se comprueba presencia. */
  quantity?: number;
  unit?: string;
};

export type PantryStock = { quantity: number; unit: string };

/**
 * La despensa puede ser un Set de ids (solo presencia, compatibilidad con el
 * matching antiguo) o un Map id → cantidad/unidad para comparar cantidades.
 */
export type Pantry = Set<string> | Map<string, PantryStock>;

export type MatchResult = {
  matchPct: number;
  /** Requeridos que no se pueden cubrir: ausentes + insuficientes. */
  missingIngredientIds: string[];
  /** Subconjunto de missing: están en la despensa pero no llega la cantidad. */
  insufficientIngredientIds: string[];
};

type UnitFamily = 'mass' | 'volume' | 'count';

// Factor a la unidad base de cada familia: g, ml, unidad.
const UNIT_TABLE: Record<string, { family: UnitFamily; factor: number }> = {
  // masa (base: g)
  g: { family: 'mass', factor: 1 },
  gr: { family: 'mass', factor: 1 },
  gramo: { family: 'mass', factor: 1 },
  gramos: { family: 'mass', factor: 1 },
  kg: { family: 'mass', factor: 1000 },
  kilo: { family: 'mass', factor: 1000 },
  kilos: { family: 'mass', factor: 1000 },
  mg: { family: 'mass', factor: 0.001 },
  // volumen (base: ml)
  ml: { family: 'volume', factor: 1 },
  cl: { family: 'volume', factor: 10 },
  dl: { family: 'volume', factor: 100 },
  l: { family: 'volume', factor: 1000 },
  litro: { family: 'volume', factor: 1000 },
  litros: { family: 'volume', factor: 1000 },
  cdita: { family: 'volume', factor: 5 },
  cucharadita: { family: 'volume', factor: 5 },
  cucharaditas: { family: 'volume', factor: 5 },
  cda: { family: 'volume', factor: 15 },
  cucharada: { family: 'volume', factor: 15 },
  cucharadas: { family: 'volume', factor: 15 },
  taza: { family: 'volume', factor: 250 },
  tazas: { family: 'volume', factor: 250 },
  vaso: { family: 'volume', factor: 200 },
  vasos: { family: 'volume', factor: 200 },
  // unidades (base: ud)
  ud: { family: 'count', factor: 1 },
  uds: { family: 'count', factor: 1 },
  u: { family: 'count', factor: 1 },
  unidad: { family: 'count', factor: 1 },
  unidades: { family: 'count', factor: 1 },
  pieza: { family: 'count', factor: 1 },
  piezas: { family: 'count', factor: 1 },
  pza: { family: 'count', factor: 1 },
};

/** Lista de unidades que la app ofrece al usuario (misma clave que UNIT_TABLE o libre). */
export const COMMON_UNITS = [
  'ud',
  'g',
  'kg',
  'ml',
  'l',
  'cdita',
  'cda',
  'taza',
  'diente',
  'rebanada',
  'loncha',
  'manojo',
  'hoja',
  'pizca',
];

export function normalizeUnit(unit: string | undefined | null): string {
  return (unit ?? 'ud').trim().toLowerCase().replace(/\.$/, '');
}

/** Convierte a la unidad base de su familia. Null si la unidad no está tabulada. */
export function toBase(quantity: number, unit: string) {
  const entry = UNIT_TABLE[normalizeUnit(unit)];
  if (!entry) return null;
  return { family: entry.family, amount: quantity * entry.factor };
}

/** "dientes" → "diente", para comparar unidades libres entre sí. */
function singular(unit: string) {
  const u = normalizeUnit(unit);
  return u.endsWith('s') && u.length > 3 ? u.slice(0, -1) : u;
}

/**
 * ¿La cantidad de la despensa cubre lo que pide la receta?
 *
 * - Misma familia (masa, volumen, unidades) → se convierten y se comparan.
 * - Misma unidad libre ("diente" vs "dientes") → se comparan tal cual.
 * - Unidades incompatibles o desconocidas (p. ej. "1 ud" de ajo frente a
 *   "2 dientes") → no se puede saber; se da por cubierto para no penalizar.
 * - Cantidad 0 en la despensa → se ha acabado, no cubre.
 */
export function covers(have: PantryStock, need: { quantity?: number; unit?: string }) {
  if (!(have.quantity > 0)) return false;
  if (need.quantity == null || !(need.quantity > 0)) return true;

  const h = toBase(have.quantity, have.unit);
  const n = toBase(need.quantity, need.unit ?? 'ud');
  if (h && n) {
    if (h.family !== n.family) return true;
    return h.amount + 1e-9 >= n.amount;
  }
  if (singular(have.unit) === singular(need.unit ?? 'ud')) {
    return have.quantity + 1e-9 >= need.quantity;
  }
  return true;
}

export function computeMatch(
  ingredients: MatchInput[],
  pantry: Pantry,
): MatchResult {
  const required = ingredients.filter((i) => !i.optional);
  if (required.length === 0) {
    return { matchPct: 100, missingIngredientIds: [], insufficientIngredientIds: [] };
  }
  const missingIngredientIds: string[] = [];
  const insufficientIngredientIds: string[] = [];
  for (const i of required) {
    if (pantry instanceof Map) {
      const stock = pantry.get(i.ingredientId);
      if (!stock) {
        missingIngredientIds.push(i.ingredientId);
      } else if (!covers(stock, i)) {
        missingIngredientIds.push(i.ingredientId);
        insufficientIngredientIds.push(i.ingredientId);
      }
    } else if (!pantry.has(i.ingredientId)) {
      missingIngredientIds.push(i.ingredientId);
    }
  }
  const covered = required.length - missingIngredientIds.length;
  const matchPct = Math.round((1000 * covered) / required.length) / 10;
  return { matchPct, missingIngredientIds, insufficientIngredientIds };
}
