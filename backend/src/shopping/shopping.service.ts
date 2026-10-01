import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { ShoppingItem } from '../entities/shopping-item.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { Recipe } from '../entities/recipe.entity';
import { PantryService } from '../pantry/pantry.service';
import { computeMatch, normalizeUnit, toBase } from '../recipes/compute-match';

export type ShoppingLine = {
  ingredientId: string;
  quantity?: number;
  unit?: string;
  recipeId?: string | null;
};

@Injectable()
export class ShoppingService {
  constructor(
    @InjectRepository(ShoppingItem)
    private readonly items: Repository<ShoppingItem>,
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    private readonly pantry: PantryService,
  ) {}

  list(userId: string) {
    return this.items.find({
      where: { userId },
      relations: { ingredient: true },
      order: { checked: 'ASC', createdAt: 'ASC' },
    });
  }

  /**
   * Añade una línea. Si el ingrediente ya está en la lista y la unidad es la
   * misma, suma cantidades; si no, deja la mayor y la unidad nueva.
   */
  async add(userId: string, line: ShoppingLine) {
    const ingredient = await this.ingredients.findOne({
      where: { id: line.ingredientId },
    });
    if (!ingredient) throw new NotFoundException('Ingredient not found');
    const saved = await this.upsert(userId, line);
    saved.ingredient = ingredient;
    return saved;
  }

  /**
   * Deja cada línea al menos en esa cantidad. Si ya había más, no la baja
   * ni la suma: volver a pulsar el planificador no duplica la compra.
   */
  async ensureAtLeast(userId: string, lines: ShoppingLine[]) {
    const saved: ShoppingItem[] = [];
    for (const line of lines) {
      const ingredient = await this.ingredients.findOne({
        where: { id: line.ingredientId },
      });
      if (!ingredient) continue;
      const item = await this.upsert(userId, line, 'atLeast');
      item.ingredient = ingredient;
      saved.push(item);
    }
    return saved;
  }

  /**
   * Añade a la lista todo lo que falta (o no llega) para una receta, teniendo
   * en cuenta la despensa actual. Devuelve las líneas añadidas/actualizadas.
   */
  async addMissingFromRecipe(userId: string, recipeId: string) {
    const recipe = await this.recipes.findOne({
      where: { id: recipeId },
      relations: { ingredients: { ingredient: true } },
    });
    if (!recipe) throw new NotFoundException('Recipe not found');
    const stock = await this.pantry.pantryStock(userId);
    const { missingIngredientIds, insufficientIngredientIds } = computeMatch(
      recipe.ingredients ?? [],
      stock,
    );
    const needed = new Set([...missingIngredientIds, ...insufficientIngredientIds]);
    const added: ShoppingItem[] = [];
    for (const ri of recipe.ingredients ?? []) {
      if (!needed.has(ri.ingredientId)) continue;
      const have = stock.get(ri.ingredientId);
      let quantity = Number(ri.quantity) || 1;
      // Si ya hay algo en la misma unidad, compramos sólo la diferencia.
      if (have && normalizeUnit(have.unit) === normalizeUnit(ri.unit)) {
        quantity = Math.max(quantity - have.quantity, 0) || quantity;
      }
      const saved = await this.upsert(userId, {
        ingredientId: ri.ingredientId,
        quantity,
        unit: ri.unit,
        recipeId,
      });
      saved.ingredient = ri.ingredient;
      added.push(saved);
    }
    return { added, items: await this.list(userId) };
  }

  async update(
    userId: string,
    id: string,
    data: { checked?: boolean; quantity?: number; unit?: string },
  ) {
    const item = await this.items.findOne({
      where: { id, userId },
      relations: { ingredient: true },
    });
    if (!item) throw new NotFoundException('Shopping item not found');
    if (data.checked !== undefined) item.checked = data.checked;
    if (data.quantity !== undefined) item.quantity = data.quantity;
    if (data.unit !== undefined) item.unit = data.unit;
    return this.items.save(item);
  }

  async remove(userId: string, id: string) {
    const item = await this.items.findOne({ where: { id, userId } });
    if (!item) throw new NotFoundException('Shopping item not found');
    await this.items.remove(item);
    return { ok: true };
  }

  async clear(userId: string, onlyChecked = false) {
    const where = onlyChecked ? { userId, checked: true } : { userId };
    const result = await this.items.delete(where);
    return { removed: result.affected ?? 0 };
  }

  /**
   * "Ya lo he comprado": pasa las líneas marcadas a la despensa (sumando a lo
   * que hubiera en la misma unidad) y las quita de la lista.
   */
  async checkout(userId: string) {
    const checked = await this.items.find({
      where: { userId, checked: true },
      relations: { ingredient: true },
    });
    const stock = await this.pantry.pantryStock(userId);
    let moved = 0;
    for (const item of checked) {
      const have = stock.get(item.ingredientId);
      const sameUnit =
        have && normalizeUnit(have.unit) === normalizeUnit(item.unit);
      await this.pantry.create(userId, {
        ingredientId: item.ingredientId,
        quantity: sameUnit ? have!.quantity + item.quantity : item.quantity,
        unit: item.unit,
      });
      await this.items.remove(item);
      moved++;
    }
    return { moved, items: await this.list(userId) };
  }

  private async upsert(userId: string, line: ShoppingLine, mode: 'add' | 'atLeast' = 'add') {
    const existing = await this.items.findOne({
      where: { userId, ingredientId: line.ingredientId },
    });
    const quantity = line.quantity ?? 1;
    const unit = line.unit ?? 'ud';
    if (existing) {
      if (mode === 'atLeast') {
        this.applyAtLeast(existing, quantity, unit);
      } else if (normalizeUnit(existing.unit) === normalizeUnit(unit)) {
        existing.quantity = existing.quantity + quantity;
      } else {
        existing.quantity = Math.max(existing.quantity, quantity);
        existing.unit = unit;
      }
      existing.checked = false;
      if (mode === 'add') existing.recipeId = line.recipeId ?? existing.recipeId;
      return this.items.save(existing);
    }
    return this.items.save(
      this.items.create({
        userId,
        ingredientId: line.ingredientId,
        quantity,
        unit,
        recipeId: line.recipeId ?? null,
        checked: false,
      }),
    );
  }

  /** Sube la línea hasta la cantidad pedida si todavía no llega. */
  private applyAtLeast(existing: ShoppingItem, quantity: number, unit: string) {
    const next = toBase(quantity, unit);
    const have = toBase(existing.quantity, existing.unit);
    if (next && have && next.family === have.family) {
      if (have.amount + 1e-9 >= next.amount) return;
      existing.quantity = quantity;
      existing.unit = unit;
      return;
    }
    if (normalizeUnit(existing.unit) === normalizeUnit(unit)) {
      existing.quantity = Math.max(existing.quantity, quantity);
      return;
    }
    existing.quantity = quantity;
    existing.unit = unit;
  }
}
