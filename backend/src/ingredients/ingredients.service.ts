import { BadRequestException, Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike, Like } from 'typeorm';
import { Ingredient } from '../entities/ingredient.entity';
import { SearchService } from '../search/search.service';
import { DEFAULT_CATEGORIES, fold, normalizeName } from './normalize';

@Injectable()
export class IngredientsService {
  constructor(
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
    private readonly searchService: SearchService,
  ) {}

  async findAll(q?: string, category?: string, limit?: number) {
    const take = Math.min(Math.max(limit ?? 80, 1), 500);
    if (q && this.searchService.isReady()) {
      const hits = await this.searchService.searchIngredients(q);
      if (hits.length) {
        return hits.filter((h) => !category || h.category === category);
      }
    }
    const where: Record<string, unknown> = {};
    if (category) where.category = category;
    if (!q) {
      return this.ingredients.find({ where, order: { name: 'ASC' }, take });
    }
    const driver = this.ingredients.manager.connection.options.type;
    const nameFilter = driver === 'postgres' ? ILike(`%${q}%`) : Like(`%${q}%`);
    return this.ingredients.find({
      where: { ...where, name: nameFilter },
      order: { name: 'ASC' },
      take: 20,
    });
  }

  findById(id: string) {
    return this.ingredients.findOne({ where: { id } });
  }

  /** Categorías del catálogo: las fijas más las que existan en BD. */
  async categories() {
    const rows = await this.ingredients
      .createQueryBuilder('i')
      .select('DISTINCT i.category', 'category')
      .getRawMany<{ category: string }>();
    const found = rows.map((r) => r.category).filter(Boolean);
    const all = new Set([...DEFAULT_CATEGORIES, ...found]);
    // "Otros" siempre al final.
    return [...all]
      .filter((c) => c !== 'Otros')
      .sort((a, b) => a.localeCompare(b, 'es'))
      .concat('Otros');
  }

  /**
   * Devuelve el ingrediente con ese nombre (o alias) si existe; si no, lo crea.
   * La comparación ignora mayúsculas y espacios sobrantes.
   */
  async createOrGet(rawName: string, category?: string) {
    const name = normalizeName(rawName);
    if (!name) throw new BadRequestException('Ingredient name is required');
    const existing = await this.findByNameOrAlias(name);
    if (existing) return existing;

    const created = await this.ingredients.save(
      this.ingredients.create({
        name,
        category: category && category.trim() ? category.trim() : 'Otros',
        aliases: [],
      }),
    );
    await this.searchService.upsertIngredient(created);
    return created;
  }

  /**
   * Busca por nombre o alias ignorando mayúsculas y acentos ("jamon york" ==
   * "Jamón york"). El catálogo es pequeño (cientos), así que se compara en
   * memoria: en SQL no hay forma portable de quitar acentos.
   */
  private async findByNameOrAlias(name: string) {
    const target = fold(name);
    const all = await this.ingredients.find({
      select: { id: true, name: true, aliases: true, category: true },
    });
    return (
      all.find((i) => fold(i.name) === target) ??
      all.find((i) => (i.aliases ?? []).some((a) => fold(a) === target)) ??
      null
    );
  }
}
