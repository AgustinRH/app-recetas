export const DEFAULT_CATEGORIES = [
  'Lácteos',
  'Verduras',
  'Frutas',
  'Carnes',
  'Pescados',
  'Cereales',
  'Legumbres',
  'Especias',
  'Condimentos',
  'Otros',
];

/** Clave de comparación: minúsculas, sin acentos ni espacios sobrantes. */
export function fold(s: string) {
  return s
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .trim()
    .replace(/\s+/g, ' ');
}

/** "  dorada  " → "Dorada"; respeta mayúsculas internas ("Aceite de oliva"). */
export function normalizeName(raw: string) {
  const collapsed = raw.trim().replace(/\s+/g, ' ');
  if (!collapsed) return '';
  return collapsed.charAt(0).toUpperCase() + collapsed.slice(1);
}
