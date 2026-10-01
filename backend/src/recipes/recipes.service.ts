import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, In, Like, Repository } from 'typeorm';
import { Recipe } from '../entities/recipe.entity';
import { RecipeIngredient } from '../entities/recipe-ingredient.entity';
import { RecipeStep } from '../entities/recipe-step.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { Like as LikeEntity } from '../entities/like.entity';
import { Comment } from '../entities/comment.entity';
import { SavedRecipe } from '../entities/saved-recipe.entity';
import { CookedRecipe } from '../entities/cooked-recipe.entity';
import { PantryService } from '../pantry/pantry.service';
import { SearchService } from '../search/search.service';
import { RedisService } from '../redis/redis.service';
import { StorageService } from '../storage/storage.service';
import { todayInMadrid } from '../common/madrid-date';
import { awardBadges } from '../users/badges';
import { computeMatch, covers } from './compute-match';

export type CreateRecipeInput = {
  title: string;
  description?: string;
  prepMinutes?: number;
  cuisine?: string;
  dietTags?: string[];
  calories?: number;
  protein?: number;
  carbs?: number;
  fat?: number;
  servings?: number;
  difficulty?: string;
  ingredients: {
    ingredientId: string;
    quantity?: number;
    unit?: string;
    optional?: boolean;
  }[];
  steps: string[];
};

export const DIFFICULTIES = ['fácil', 'media', 'difícil'] as const;

export type FeedFilters = {
  maxMinutes?: number;
  cuisine?: string;
  diet?: string;
  following?: boolean;
};

const FEED_CACHE_KEY = 'feed:first-page';

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
    @InjectRepository(CookedRecipe) private readonly cooks: Repository<CookedRecipe>,
    private readonly dataSource: DataSource,
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
      protein: input.protein ?? null,
      carbs: input.carbs ?? null,
      fat: input.fat ?? null,
      servings: input.servings ?? 2,
      difficulty: input.difficulty ?? 'fácil',
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
    await this.redis.del(FEED_CACHE_KEY);
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
    await this.redis.del(FEED_CACHE_KEY);
    return { photoUrl: recipe.photoUrl };
  }

  async suggested(
    userId: string,
    filters: { maxMinutes?: number; cuisine?: string; diet?: string; q?: string },
  ) {
    const stock = await this.pantry.pantryStock(userId);
    let recipes = await this.loadRecipesForMatch(filters);
    if (filters.q) {
      recipes = await this.filterByQuery(recipes, filters.q);
    }
    const scored = recipes.map((recipe) => {
      const { matchPct, missingIngredientIds } = computeMatch(
        recipe.ingredients ?? [],
        stock,
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

  async searchRecipes(
    userId: string,
    q: string,
    fromPantry?: boolean,
    filters: FeedFilters = {},
  ) {
    if (fromPantry) {
      return this.suggested(userId, { ...filters, q });
    }
    const recipes = await this.filterByQuery(
      await this.loadRecipesForMatch(filters),
      q,
    );
    const social = await this.socialFlags(
      userId,
      recipes.map((r) => r.id),
    );
    return recipes.map((r) => this.serializeList(r, social.get(r.id)));
  }

  async feed(
    userId: string,
    cursor?: string,
    limit = 20,
    filters: FeedFilters = {},
  ) {
    const take = Math.min(Math.max(limit, 1), 50);
    const hasFilters = Boolean(
      filters.maxMinutes || filters.cuisine || filters.diet || filters.following,
    );
    const cacheable = !cursor && !hasFilters && take === 20;
    let rows: Recipe[] | null = null;
    if (cacheable) {
      const cached = await this.redis.get(FEED_CACHE_KEY);
      if (cached) rows = JSON.parse(cached) as Recipe[];
    }
    if (!rows) {
      const qb = this.recipes
        .createQueryBuilder('r')
        .leftJoinAndSelect('r.author', 'author')
        .leftJoinAndSelect('r.ingredients', 'ingredients')
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
      if (filters.maxMinutes) {
        qb.andWhere('r.prepMinutes <= :maxMinutes', {
          maxMinutes: filters.maxMinutes,
        });
      }
      if (filters.cuisine) {
        qb.andWhere('r.cuisine = :cuisine', { cuisine: filters.cuisine });
      }
      if (filters.following) {
        qb.innerJoin(
          'follows',
          'fol',
          'fol."followingId" = r."authorId" AND fol."followerId" = :followerId',
          { followerId: userId },
        );
      }
      rows = await qb.getMany();
      if (filters.diet) {
        rows = rows.filter((r) => (r.dietTags ?? []).includes(filters.diet!));
      }
      if (cacheable) {
        await this.redis.setex(FEED_CACHE_KEY, 30, JSON.stringify(rows));
      }
    }
    // El feed es cronológico, pero cada tarjeta lleva su % de coincidencia
    // con la despensa para que la app pueda destacar lo que se puede cocinar ya.
    const stock = await this.pantry.pantryStock(userId);
    const social = await this.socialFlags(
      userId,
      rows.map((r) => r.id),
    );
    const items = rows.map((r) => {
      const { matchPct, missingIngredientIds } = computeMatch(
        r.ingredients ?? [],
        stock,
      );
      return this.serializeList(r, social.get(r.id), {
        matchPct,
        missingCount: missingIngredientIds.length,
      });
    });
    const last = rows[rows.length - 1];
    const nextCursor = last
      ? `${new Date(last.createdAt).toISOString()}|${last.id}`
      : null;
    return { items, nextCursor };
  }

  /** Cocinas presentes en el catálogo, ordenadas alfabéticamente. */
  async cuisines(): Promise<string[]> {
    const rows = await this.recipes
      .createQueryBuilder('r')
      .select('DISTINCT r.cuisine', 'cuisine')
      .getRawMany<{ cuisine: string }>();
    return rows
      .map((r) => r.cuisine)
      .filter(Boolean)
      .sort((a, b) => a.localeCompare(b, 'es'));
  }

  async findDetail(recipeId: string, userId: string | null) {
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
    const stock = userId ? await this.pantry.pantryStock(userId) : new Map();
    const matched = userId
      ? computeMatch(recipe.ingredients ?? [], stock)
      : null;
    const missingIngredientIds = matched?.missingIngredientIds ?? [];
    const insufficient = new Set(matched?.insufficientIngredientIds ?? []);
    const describe = (ri: RecipeIngredient) => {
      const have = stock.get(ri.ingredientId);
      return {
        id: ri.ingredient.id,
        name: ri.ingredient.name,
        category: ri.ingredient.category,
        quantity: ri.quantity,
        unit: ri.unit,
        optional: ri.optional,
        /** Está en la despensa (aunque no llegue la cantidad). */
        inPantry: Boolean(have),
        /** Está y la cantidad cubre lo que pide la receta (o es opcional y falta). */
        enough: ri.optional
          ? have
            ? covers(have, ri)
            : false
          : Boolean(have) && !insufficient.has(ri.ingredientId),
        pantryQuantity: have?.quantity ?? null,
        pantryUnit: have?.unit ?? null,
      };
    };
    const missing = (recipe.ingredients ?? [])
      .filter((ri) => missingIngredientIds.includes(ri.ingredientId))
      .map(describe);
    const social = await this.socialFlags(userId, [recipe.id]);
    const flags = social.get(recipe.id);
    const cookedOn = todayInMadrid();
    const [cookedCount, cookedToday] = userId
      ? await Promise.all([
          this.cooks.count({ where: { userId, recipeId } }),
          this.cooks.exists({ where: { userId, recipeId, cookedOn } }),
        ])
      : [0, false];
    return {
      ...this.serializeList(
        recipe,
        flags,
        matched
          ? { matchPct: matched.matchPct, missingCount: missing.length }
          : undefined,
      ),
      description: recipe.description,
      calories: recipe.calories,
      protein: recipe.protein,
      carbs: recipe.carbs,
      fat: recipe.fat,
      cookedCount,
      cookedToday,
      ingredients: (recipe.ingredients ?? []).map(describe),
      steps: (recipe.steps ?? []).map((s) => ({
        position: s.position,
        body: s.body,
      })),
      missingIngredients: userId ? missing : [],
      followingAuthor: await this.isFollowingAuthor(userId, recipe.authorId),
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
    await this.redis.del(FEED_CACHE_KEY);
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

  /** Apunta que hoy has cocinado la receta. Repetir el mismo día no suma otra vez. */
  async markCooked(userId: string, recipeId: string) {
    await this.ensureRecipe(recipeId);
    const cookedOn = todayInMadrid();
    const existing = await this.cooks.findOne({ where: { userId, recipeId, cookedOn } });
    if (!existing) {
      try {
        await this.cooks.save(this.cooks.create({ userId, recipeId, cookedOn }));
      } catch (error) {
        const code = (error as { driverError?: { code?: string } }).driverError?.code;
        if (code !== '23505') throw error;
      }
    }
    const times = await this.cooks.count({ where: { userId, recipeId } });
    const recipe = await this.recipes.findOne({
      where: { id: recipeId },
      relations: { ingredients: true },
    });
    const stock = await this.pantry.pantryStock(userId);
    const { missingIngredientIds } = computeMatch(recipe?.ingredients ?? [], stock);
    const codes = ['primera-cocina'];
    if (missingIngredientIds.length === 0) codes.push('cero-desperdicio');
    await awardBadges(this.dataSource, userId, codes);
    return { cookedOn, cookedToday: true, times };
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
    await this.redis.del(FEED_CACHE_KEY);
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

  private async isFollowingAuthor(userId: string | null, authorId: string | null) {
    if (!userId || !authorId || userId === authorId) return false;
    const rows = await this.dataSource.query<{ ok: boolean }[]>(
      `SELECT EXISTS (
         SELECT 1 FROM follows WHERE "followerId" = $1 AND "followingId" = $2
       ) AS ok`,
      [userId, authorId],
    );
    return Boolean(rows[0]?.ok);
  }

  private async socialFlags(userId: string | null, recipeIds: string[]) {
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
      userId
        ? this.likes.find({ where: { userId, recipeId: In(recipeIds) } })
        : Promise.resolve([]),
      userId
        ? this.saves.find({ where: { userId, recipeId: In(recipeIds) } })
        : Promise.resolve([]),
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
      dietTags: recipe.dietTags ?? [],
      difficulty: recipe.difficulty ?? 'fácil',
      servings: recipe.servings ?? 2,
      calories: recipe.calories ?? null,
      ingredientsCount: recipe.ingredients?.length ?? undefined,
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
