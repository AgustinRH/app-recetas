import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { In, Like, Repository } from 'typeorm';
import { Recipe } from '../entities/recipe.entity';
import { RecipeIngredient } from '../entities/recipe-ingredient.entity';
import { RecipeStep } from '../entities/recipe-step.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { Like as LikeEntity } from '../entities/like.entity';
import { Comment } from '../entities/comment.entity';
import { SavedRecipe } from '../entities/saved-recipe.entity';
import { PantryService } from '../pantry/pantry.service';
import { SearchService } from '../search/search.service';
import { RedisService } from '../redis/redis.service';
import { StorageService } from '../storage/storage.service';
import { computeMatch } from './compute-match';

export type CreateRecipeInput = {
  title: string;
  description?: string;
  prepMinutes?: number;
  cuisine?: string;
  dietTags?: string[];
  calories?: number;
  ingredients: {
    ingredientId: string;
    quantity?: number;
    unit?: string;
    optional?: boolean;
  }[];
  steps: string[];
};

@Injectable()
export class RecipesService {
  constructor(
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    @InjectRepository(RecipeIngredient)
    private readonly recipeIngredients: Repository<RecipeIngredient>,
    @InjectRepository(RecipeStep) private readonly steps: Repository<RecipeStep>,
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
    @InjectRepository(LikeEntity) private readonly likes: Repository<LikeEntity>,
    @InjectRepository(Comment) private readonly comments: Repository<Comment>,
    @InjectRepository(SavedRecipe) private readonly saves: Repository<SavedRecipe>,
    private readonly pantry: PantryService,
    private readonly search: SearchService,
    private readonly redis: RedisService,
    private readonly storage: StorageService,
  ) {}

  async create(authorId: string, input: CreateRecipeInput) {
    if (!input.ingredients?.length) {
      throw new BadRequestException('A recipe needs at least one ingredient');
    }
    if (!input.steps?.length) {
      throw new BadRequestException('A recipe needs at least one step');
    }
    const ids = input.ingredients.map((i) => i.ingredientId);
    const found = await this.ingredients.find({ where: { id: In(ids) } });
    if (found.length !== new Set(ids).size) {
      throw new BadRequestException('Unknown ingredient in recipe');
    }
    const recipe = this.recipes.create({
      authorId,
      title: input.title,
      description: input.description ?? '',
      prepMinutes: input.prepMinutes ?? 30,
      cuisine: input.cuisine ?? 'Mediterránea',
      dietTags: input.dietTags ?? [],
      calories: input.calories ?? null,
    });
    const saved = await this.recipes.save(recipe);
    saved.ingredients = await this.recipeIngredients.save(
      input.ingredients.map((i) =>
        this.recipeIngredients.create({
          recipeId: saved.id,
          ingredientId: i.ingredientId,
          quantity: i.quantity ?? 1,
          unit: i.unit ?? 'ud',
          optional: Boolean(i.optional),
        }),
      ),
    );
    saved.steps = await this.steps.save(
      input.steps.map((body, index) =>
        this.steps.create({ recipeId: saved.id, position: index + 1, body }),
      ),
    );
    await this.search.upsertRecipe(saved);
    await this.redis.del('feed:first-page');
    return this.findDetail(saved.id, authorId);
  }

  async uploadPhoto(
    userId: string,
    recipeId: string,
    file: Express.Multer.File,
  ) {
    const recipe = await this.recipes.findOne({ where: { id: recipeId } });
    if (!recipe) throw new NotFoundException('Recipe not found');
    if (recipe.authorId !== userId) {
      throw new BadRequestException('Only the author can upload a photo');
    }
    recipe.photoUrl = await this.storage.saveRecipePhoto(
      recipeId,
      file.buffer,
      file.mimetype,
    );
    await this.recipes.save(recipe);
    await this.redis.del('feed:first-page');
    return { photoUrl: recipe.photoUrl };
  }

  async suggested(
    userId: string,
    filters: { maxMinutes?: number; cuisine?: string; diet?: string; q?: string },
  ) {
    const pantryIds = await this.pantry.pantryIngredientIds(userId);
    let recipes = await this.loadRecipesForMatch(filters);
    if (filters.q) {
      recipes = await this.filterByQuery(recipes, filters.q);
    }
    const scored = recipes.map((recipe) => {
      const { matchPct, missingIngredientIds } = computeMatch(
        recipe.ingredients ?? [],
        pantryIds,
      );
      return { recipe, matchPct, missingIngredientIds };
    });
    scored.sort((a, b) => b.matchPct - a.matchPct || a.recipe.title.localeCompare(b.recipe.title));
    const social = await this.socialFlags(
      userId,
      scored.map((s) => s.recipe.id),
    );
    return scored.map((s) =>
      this.serializeList(s.recipe, social.get(s.recipe.id), {
        matchPct: s.matchPct,
        missingCount: s.missingIngredientIds.length,
      }),
    );
  }

  async searchRecipes(userId: string, q: string, fromPantry?: boolean) {
    if (fromPantry) {
      return this.suggested(userId, { q });
    }
    const recipes = await this.filterByQuery(
      await this.loadRecipesForMatch({}),
      q,
    );
    const social = await this.socialFlags(
      userId,
      recipes.map((r) => r.id),
    );
    return recipes.map((r) => this.serializeList(r, social.get(r.id)));
  }

  async feed(userId: string, cursor?: string, limit = 20) {
    const take = Math.min(Math.max(limit, 1), 50);
    let rows: Recipe[] | null = null;
    if (!cursor) {
      const cached = await this.redis.get('feed:first-page');
      if (cached) rows = JSON.parse(cached) as Recipe[];
    }
    if (!rows) {
      const qb = this.recipes
        .createQueryBuilder('r')
        .leftJoinAndSelect('r.author', 'author')
        .orderBy('r.createdAt', 'DESC')
        .addOrderBy('r.id', 'DESC')
        .take(take);
      if (cursor) {
        const [createdAt, id] = cursor.split('|');
        qb.andWhere(
          '(r.createdAt < :createdAt OR (r.createdAt = :createdAt AND r.id < :id))',
          { createdAt, id },
        );
      }
      rows = await qb.getMany();
      if (!cursor) {
        await this.redis.setex('feed:first-page', 30, JSON.stringify(rows));
      }
    }
    const social = await this.socialFlags(
      userId,
      rows.map((r) => r.id),
    );
    const items = rows.map((r) => this.serializeList(r, social.get(r.id)));
    const last = rows[rows.length - 1];
    const nextCursor = last
      ? `${new Date(last.createdAt).toISOString()}|${last.id}`
      : null;
    return { items, nextCursor };
  }

  async findDetail(recipeId: string, userId: string) {
    const recipe = await this.recipes.findOne({
      where: { id: recipeId },
      relations: {
        author: true,
        ingredients: { ingredient: true },
        steps: true,
      },
    });
    if (!recipe) throw new NotFoundException('Recipe not found');
    recipe.steps = (recipe.steps ?? []).sort((a, b) => a.position - b.position);
    const pantryIds = await this.pantry.pantryIngredientIds(userId);
    const { matchPct, missingIngredientIds } = computeMatch(
      recipe.ingredients ?? [],
      pantryIds,
    );
    const missing = (recipe.ingredients ?? [])
      .filter((ri) => missingIngredientIds.includes(ri.ingredientId))
      .map((ri) => ({
        id: ri.ingredient.id,
        name: ri.ingredient.name,
        quantity: ri.quantity,
        unit: ri.unit,
      }));
    const social = await this.socialFlags(userId, [recipe.id]);
    const flags = social.get(recipe.id);
    return {
      ...this.serializeList(recipe, flags, { matchPct, missingCount: missing.length }),
      description: recipe.description,
      calories: recipe.calories,
      dietTags: recipe.dietTags ?? [],
      ingredients: (recipe.ingredients ?? []).map((ri) => ({
        id: ri.ingredient.id,
        name: ri.ingredient.name,
        category: ri.ingredient.category,
        quantity: ri.quantity,
        unit: ri.unit,
        optional: ri.optional,
        inPantry: pantryIds.has(ri.ingredientId),
      })),
      steps: (recipe.steps ?? []).map((s) => ({
        position: s.position,
        body: s.body,
      })),
      missingIngredients: missing,
    };
  }

  async myRecipes(userId: string) {
    const recipes = await this.recipes.find({
      where: { authorId: userId },
      relations: { author: true },
      order: { createdAt: 'DESC' },
    });
    const social = await this.socialFlags(
      userId,
      recipes.map((r) => r.id),
    );
    return recipes.map((r) => this.serializeList(r, social.get(r.id)));
  }

  async savedRecipes(userId: string) {
    const saved = await this.saves.find({
      where: { userId },
      relations: { recipe: { author: true } },
      order: { createdAt: 'DESC' },
    });
    const recipes = saved.map((s) => s.recipe).filter(Boolean);
    const social = await this.socialFlags(
      userId,
      recipes.map((r) => r.id),
    );
    return recipes.map((r) => this.serializeList(r, social.get(r.id)));
  }

  async toggleLike(userId: string, recipeId: string, liked: boolean) {
    await this.ensureRecipe(recipeId);
    const existing = await this.likes.findOne({ where: { userId, recipeId } });
    if (liked && !existing) {
      await this.likes.save(this.likes.create({ userId, recipeId }));
    }
    if (!liked && existing) await this.likes.remove(existing);
    await this.redis.del('feed:first-page');
    return { liked };
  }

  async toggleSave(userId: string, recipeId: string, saved: boolean) {
    await this.ensureRecipe(recipeId);
    const existing = await this.saves.findOne({ where: { userId, recipeId } });
    if (saved && !existing) {
      await this.saves.save(this.saves.create({ userId, recipeId }));
    }
    if (!saved && existing) await this.saves.remove(existing);
    return { saved };
  }

  async listComments(recipeId: string) {
    await this.ensureRecipe(recipeId);
    const rows = await this.comments.find({
      where: { recipeId },
      relations: { user: true },
      order: { createdAt: 'ASC' },
    });
    return rows.map((c) => ({
      id: c.id,
      body: c.body,
      createdAt: c.createdAt,
      author: {
        id: c.user.id,
        displayName: c.user.displayName,
        avatarUrl: c.user.avatarUrl,
      },
    }));
  }

  async addComment(userId: string, recipeId: string, body: string) {
    await this.ensureRecipe(recipeId);
    const saved = await this.comments.save(
      this.comments.create({ userId, recipeId, body }),
    );
    await this.redis.del('feed:first-page');
    return this.listComments(recipeId).then(
      (all) => all.find((c) => c.id === saved.id)!,
    );
  }

  private async ensureRecipe(id: string) {
    const exists = await this.recipes.findOne({ where: { id } });
    if (!exists) throw new NotFoundException('Recipe not found');
  }

  private async loadRecipesForMatch(filters: {
    maxMinutes?: number;
    cuisine?: string;
    diet?: string;
  }) {
    const qb = this.recipes
      .createQueryBuilder('r')
      .leftJoinAndSelect('r.author', 'author')
      .leftJoinAndSelect('r.ingredients', 'ingredients');
    if (filters.maxMinutes) {
      qb.andWhere('r.prepMinutes <= :maxMinutes', {
        maxMinutes: filters.maxMinutes,
      });
    }
    if (filters.cuisine) {
      qb.andWhere('r.cuisine = :cuisine', { cuisine: filters.cuisine });
    }
    const recipes = await qb.getMany();
    if (filters.diet) {
      return recipes.filter((r) => (r.dietTags ?? []).includes(filters.diet!));
    }
    return recipes;
  }

  private async filterByQuery(recipes: Recipe[], q: string) {
    const ids = await this.search.searchRecipes(q);
    if (ids.length) {
      const set = new Set(ids);
      return recipes.filter((r) => set.has(r.id));
    }
    const needle = q.toLowerCase();
    const fromSql = await this.recipes.find({
      where: { title: Like(`%${q}%`) },
    });
    const sqlIds = new Set(fromSql.map((r) => r.id));
    return recipes.filter(
      (r) =>
        sqlIds.has(r.id) ||
        r.title.toLowerCase().includes(needle) ||
        (r.description ?? '').toLowerCase().includes(needle),
    );
  }

  private async socialFlags(userId: string, recipeIds: string[]) {
    const map = new Map<
      string,
      { likesCount: number; commentsCount: number; isLiked: boolean; isSaved: boolean }
    >();
    if (!recipeIds.length) return map;
    const [likeRows, commentRows, userLikes, userSaves] = await Promise.all([
      this.likes
        .createQueryBuilder('l')
        .select('l.recipeId', 'recipeId')
        .addSelect('COUNT(*)', 'count')
        .where('l.recipeId IN (:...ids)', { ids: recipeIds })
        .groupBy('l.recipeId')
        .getRawMany<{ recipeId: string; count: string }>(),
      this.comments
        .createQueryBuilder('c')
        .select('c.recipeId', 'recipeId')
        .addSelect('COUNT(*)', 'count')
        .where('c.recipeId IN (:...ids)', { ids: recipeIds })
        .groupBy('c.recipeId')
        .getRawMany<{ recipeId: string; count: string }>(),
      this.likes.find({ where: { userId, recipeId: In(recipeIds) } }),
      this.saves.find({ where: { userId, recipeId: In(recipeIds) } }),
    ]);
    const liked = new Set(userLikes.map((l) => l.recipeId));
    const saved = new Set(userSaves.map((s) => s.recipeId));
    const likesCount = new Map(likeRows.map((r) => [r.recipeId, Number(r.count)]));
    const commentsCount = new Map(
      commentRows.map((r) => [r.recipeId, Number(r.count)]),
    );
    for (const id of recipeIds) {
      map.set(id, {
        likesCount: likesCount.get(id) ?? 0,
        commentsCount: commentsCount.get(id) ?? 0,
        isLiked: liked.has(id),
        isSaved: saved.has(id),
      });
    }
    return map;
  }

  private serializeList(
    recipe: Recipe,
    flags?: {
      likesCount: number;
      commentsCount: number;
      isLiked: boolean;
      isSaved: boolean;
    },
    extra?: { matchPct?: number; missingCount?: number },
  ) {
    return {
      id: recipe.id,
      title: recipe.title,
      photoUrl: recipe.photoUrl,
      prepMinutes: recipe.prepMinutes,
      cuisine: recipe.cuisine,
      createdAt: recipe.createdAt,
      author: recipe.author
        ? {
            id: recipe.author.id,
            displayName: recipe.author.displayName,
            avatarUrl: recipe.author.avatarUrl,
          }
        : null,
      likesCount: flags?.likesCount ?? 0,
      commentsCount: flags?.commentsCount ?? 0,
      isLiked: flags?.isLiked ?? false,
      isSaved: flags?.isSaved ?? false,
      matchPct: extra?.matchPct,
      missingCount: extra?.missingCount,
    };
  }
}
