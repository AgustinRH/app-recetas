import { fold, normalizeName } from './normalize';

describe('fold', () => {
  it('iguala mayúsculas, acentos y espacios', () => {
    expect(fold('Jamón  York')).toBe('jamon york');
    expect(fold('jamon york')).toBe(fold('Jamón york'));
    expect(fold('Brócoli')).toBe('brocoli');
  });
});

describe('normalizeName', () => {
  it('recorta, colapsa espacios y pone mayúscula inicial', () => {
    expect(normalizeName('  dorada ')).toBe('Dorada');
    expect(normalizeName('aceite   de  oliva')).toBe('Aceite de oliva');
  });

  it('respeta mayúsculas internas', () => {
    expect(normalizeName('salsa BBQ')).toBe('Salsa BBQ');
  });

  it('devuelve vacío si solo hay espacios', () => {
    expect(normalizeName('   ')).toBe('');
  });
});
