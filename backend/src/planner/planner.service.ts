import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { MealSlot } from '../entities/meal-slot.entity';
import { Recipe } from '../entities/recipe.entity';
import { PantryService } from '../pantry/pantry.service';
import { ShoppingService } from '../shopping/shopping.service';
import { gapsForPlan, NeedInput } from './aggregate-needs';

const MEALS = ['comida', 'cena'] as const;

function assertMonday(weekStart: string) {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(weekStart)) {
    throw new BadRequestException('Semana no válida');
  }
  const date = new Date(`${weekStart}T00:00:00Z`);
  if (Number.isNaN(date.getTime()) || date.toISOString().slice(0, 10) !== weekStart) {
    throw new BadRequestException('Semana no válida');
  }
  if (date.getUTCDay() !== 1) {
    throw new BadRequestException('La semana tiene que empezar en lunes');
  }
}

@Injectable()
export class PlannerService {
  constructor(
    @InjectRepository(MealSlot) private readonly slots: Repository<MealSlot>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    private readonly pantry: PantryService,
    private readonly shopping: ShoppingService,
  ) {}

  async week(userId: string, weekStart: string) {
    assertMonday(weekStart);
    const rows = await this.slots.find({
      where: { userId, weekStart },
      relations: { recipe: { author: true, ingredients: { ingredient: true } } },
    });
    rows.sort(
      (a, b) => a.dayIndex - b.dayIndex || MEALS.indexOf(a.meal as (typeof MEALS)[number]) - MEALS.indexOf(b.meal as (typeof MEALS)[number]),
    );
    const lines: NeedInput[] = [];
    for (const slot of rows) {
      for (const ri of slot.recipe?.ingredients ?? []) {
        lines.push({
          ingredientId: ri.ingredientId,
          name: ri.ingredient?.name ?? '',
          quantity: Number(ri.quantity) || 0,
          unit: ri.unit,
          optional: ri.optional,
        });
      }
    }
    const stock = await this.pantry.pantryStock(userId);
    return {
      weekStart,
      slots: rows.map((slot) => ({
        dayIndex: slot.dayIndex,
        meal: slot.meal,
        recipe: slot.recipe
          ? {
              id: slot.recipe.id,
              title: slot.recipe.title,
              photoUrl: slot.recipe.photoUrl,
              prepMinutes: slot.recipe.prepMinutes,
              cuisine: slot.recipe.cuisine,
              authorName: slot.recipe.author?.displayName ?? null,
            }
          : null,
      })),
      gaps: gapsForPlan(lines, stock),
    };
  }

  async setSlot(
    userId: string,
    input: { weekStart: string; dayIndex: number; meal: string; recipeId?: string | null },
  ) {
    assertMonday(input.weekStart);
    if (!Number.isInteger(input.dayIndex) || input.dayIndex < 0 || input.dayIndex > 6) {
      throw new BadRequestException('Día no válido');
    }
    if (!MEALS.includes(input.meal as (typeof MEALS)[number])) {
      throw new BadRequestException('La comida tiene que ser comida o cena');
    }
    const where = {
      userId,
      weekStart: input.weekStart,
      dayIndex: input.dayIndex,
      meal: input.meal,
    };
    if (!input.recipeId) {
      await this.slots.delete(where);
      return this.week(userId, input.weekStart);
    }
    const recipe = await this.recipes.findOne({ where: { id: input.recipeId } });
    if (!recipe) throw new NotFoundException('Receta no encontrada');
    const existing = await this.slots.findOne({ where });
    if (existing) {
      existing.recipeId = input.recipeId;
      await this.slots.save(existing);
    } else {
      await this.slots.save(this.slots.create({ ...where, recipeId: input.recipeId }));
    }
    return this.week(userId, input.weekStart);
  }

  /** Deja en la lista, sin duplicar, lo que falta para toda la semana. */
  async addGapsToShopping(userId: string, weekStart: string) {
    const plan = await this.week(userId, weekStart);
    const added = await this.shopping.ensureAtLeast(
      userId,
      plan.gaps.map((gap) => ({
        ingredientId: gap.ingredientId,
        quantity: gap.quantity,
        unit: gap.unit,
      })),
    );
    return { count: added.length, gaps: plan.gaps };
  }
}
