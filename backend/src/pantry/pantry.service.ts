import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { PantryItem } from '../entities/pantry-item.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { PantryStock } from '../recipes/compute-match';

@Injectable()
export class PantryService {
  constructor(
    @InjectRepository(PantryItem)
    private readonly pantry: Repository<PantryItem>,
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
  ) {}

  list(userId: string) {
    return this.pantry.find({
      where: { userId },
      relations: { ingredient: true },
      order: { id: 'ASC' },
    });
  }

  pantryIngredientIds(userId: string) {
    return this.pantry
      .find({ where: { userId }, select: { ingredientId: true } })
      .then((rows) => new Set(rows.map((r) => r.ingredientId)));
  }

  /** ingredientId → cantidad/unidad disponible, para el matching por cantidades. */
  pantryStock(userId: string): Promise<Map<string, PantryStock>> {
    return this.pantry
      .find({
        where: { userId },
        select: { ingredientId: true, quantity: true, unit: true },
      })
      .then(
        (rows) =>
          new Map(
            rows.map((r) => [
              r.ingredientId,
              { quantity: Number(r.quantity), unit: r.unit },
            ]),
          ),
      );
  }

  async create(
    userId: string,
    data: {
      ingredientId: string;
      quantity?: number;
      unit?: string;
      expiresAt?: string | null;
    },
  ) {
    const ingredient = await this.ingredients.findOne({
      where: { id: data.ingredientId },
    });
    if (!ingredient) throw new NotFoundException('Ingredient not found');
    const existing = await this.pantry.findOne({
      where: { userId, ingredientId: data.ingredientId },
    });
    if (existing) {
      // Ya estaba: actualizamos cantidad/unidad en vez de fallar.
      existing.quantity = data.quantity ?? existing.quantity;
      existing.unit = data.unit ?? existing.unit;
      if (data.expiresAt !== undefined) existing.expiresAt = data.expiresAt;
      const updated = await this.pantry.save(existing);
      updated.ingredient = ingredient;
      return updated;
    }
    const item = this.pantry.create({
      userId,
      ingredientId: data.ingredientId,
      quantity: data.quantity ?? 1,
      unit: data.unit ?? 'ud',
      expiresAt: data.expiresAt ?? null,
    });
    const saved = await this.pantry.save(item);
    saved.ingredient = ingredient;
    return saved;
  }

  async update(
    userId: string,
    id: string,
    data: { quantity?: number; unit?: string; expiresAt?: string | null },
  ) {
    const item = await this.pantry.findOne({
      where: { id, userId },
      relations: { ingredient: true },
    });
    if (!item) throw new NotFoundException('Pantry item not found');
    if (data.quantity !== undefined) item.quantity = data.quantity;
    if (data.unit !== undefined) item.unit = data.unit;
    if (data.expiresAt !== undefined) {
      item.expiresAt = data.expiresAt;
    }
    return this.pantry.save(item);
  }

  async remove(userId: string, id: string) {
    const item = await this.pantry.findOne({ where: { id, userId } });
    if (!item) throw new NotFoundException('Pantry item not found');
    await this.pantry.remove(item);
    return { ok: true };
  }
}
