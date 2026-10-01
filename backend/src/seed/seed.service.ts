import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Ingredient } from '../entities/ingredient.entity';
import { Recipe } from '../entities/recipe.entity';
import { RecipeIngredient } from '../entities/recipe-ingredient.entity';
import { RecipeStep } from '../entities/recipe-step.entity';
import { User } from '../entities/user.entity';
import { UserPreferences } from '../entities/user-preferences.entity';
import { SearchService } from '../search/search.service';
import { INGREDIENT_SEEDS, RECIPE_SEEDS, RecipeSeed } from './seed-data';

@Injectable()
export class SeedService implements OnModuleInit {
  private readonly logger = new Logger(SeedService.name);

  constructor(
    private readonly config: ConfigService,
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    @InjectRepository(RecipeIngredient)
    private readonly recipeIngredients: Repository<RecipeIngredient>,
    @InjectRepository(RecipeStep) private readonly steps: Repository<RecipeStep>,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(UserPreferences)
    private readonly prefs: Repository<UserPreferences>,
    private readonly search: SearchService,
  ) {}

  async onModuleInit() {
    if (this.config.get('SEED_ON_START') !== 'true') return;
    await this.run();
  }

  /**
   * Añade al catálogo los ingredientes del seed que aún no existan (por nombre,
   * sin distinguir mayúsculas). No toca los existentes ni las recetas.
   * Sirve para ampliar el catálogo en una BD ya en uso.
   */
  async addMissingIngredients() {
    const existing = await this.ingredients.find({ select: { name: true } });
    const have = new Set(existing.map((i) => i.name.toLowerCase()));
    const missing = INGREDIENT_SEEDS.filter((i) => !have.has(i.name.toLowerCase()));
    if (!missing.length) return 0;
    const saved = await this.ingredients.save(
      missing.map((i) => this.ingredients.create(i)),
    );
    for (const ingredient of saved) {
      await this.search.upsertIngredient(ingredient);
    }
    this.logger.log(`Added ${saved.length} missing ingredients to the catalog`);
    return saved.length;
  }

  async run() {
    const count = await this.ingredients.count();
    if (count > 0) {
      this.logger.log('Seed skipped (ingredients already present); topping up catalog');
      await this.addMissingIngredients();
      return;
    }
    this.logger.log('Seeding ingredients and recipes…');
    const savedIngredients = await this.ingredients.save(
      INGREDIENT_SEEDS.map((i) => this.ingredients.create(i)),
    );
    const byName = new Map(savedIngredients.map((i) => [i.name, i]));
    for (const ingredient of savedIngredients) {
      await this.search.upsertIngredient(ingredient);
    }

    const author = await this.ensureSeedAuthor();

    for (const seed of RECIPE_SEEDS) {
      const recipe = await this.recipes.save(
        this.recipes.create({
          authorId: author.id,
          title: seed.title,
          description: seed.description,
          prepMinutes: seed.prepMinutes,
          cuisine: seed.cuisine,
          dietTags: seed.dietTags,
          calories: seed.calories,
          protein: seed.protein ?? null,
          carbs: seed.carbs ?? null,
          fat: seed.fat ?? null,
          servings: seed.servings ?? 2,
          difficulty: seed.difficulty ?? 'fácil',
          photoUrl: null,
        }),
      );
      await this.recipeIngredients.save(
        seed.ingredients.map((i) => {
          const ingredient = byName.get(i.name);
          if (!ingredient) {
            throw new Error(`Seed ingredient missing: ${i.name}`);
          }
          return this.recipeIngredients.create({
            recipeId: recipe.id,
            ingredientId: ingredient.id,
            quantity: i.quantity,
            unit: i.unit,
            optional: Boolean(i.optional),
          });
        }),
      );
      await this.steps.save(
        seed.steps.map((body, index) =>
          this.steps.create({ recipeId: recipe.id, position: index + 1, body }),
        ),
      );
      await this.search.upsertRecipe(recipe);
    }
    this.logger.log(
      `Seeded ${savedIngredients.length} ingredients and ${RECIPE_SEEDS.length} recipes`,
    );
  }

  /**
   * Inserta una receta del catálogo si el autor semilla aún no tiene ese título.
   * Si ya existe y no tiene foto, guarda la URL nueva.
   */
  async seedRecipeState(title: string): Promise<'missing' | 'needs-photo' | 'ready'> {
    const author = await this.ensureSeedAuthor();
    const existing = await this.recipes.findOne({
      where: { title, authorId: author.id },
      select: { id: true, photoUrl: true },
    });
    if (!existing) return 'missing';
    return existing.photoUrl ? 'ready' : 'needs-photo';
  }

  async addCatalogRecipe(
    seed: RecipeSeed & { photoUrl?: string | null },
  ): Promise<'inserted' | 'updated' | 'skipped'> {
    const byName = await this.ingredientMap();
    const author = await this.ensureSeedAuthor();
    const existing = await this.recipes.findOne({
      where: { title: seed.title, authorId: author.id },
    });
    if (existing) {
      if (!existing.photoUrl && seed.photoUrl) {
        existing.photoUrl = seed.photoUrl;
        const creditAt = seed.description?.lastIndexOf('Foto:') ?? -1;
        if (creditAt >= 0 && !existing.description.includes('Foto:')) {
          const creditLine = seed.description.slice(creditAt).trim();
          existing.description =
            seed.ingredients.length > 0
              ? seed.description
              : `${existing.description}\n\n${creditLine}`;
        }
        await this.recipes.save(existing);
        return 'updated';
      }
      return 'skipped';
    }
    if (!seed.ingredients.length || !seed.steps.length) return 'skipped';
    const recipe = await this.recipes.save(
      this.recipes.create({
        authorId: author.id,
        title: seed.title,
        description: seed.description,
        prepMinutes: seed.prepMinutes,
        cuisine: seed.cuisine,
        dietTags: seed.dietTags,
        calories: seed.calories,
        protein: seed.protein ?? null,
        carbs: seed.carbs ?? null,
        fat: seed.fat ?? null,
        servings: seed.servings ?? 2,
        difficulty: seed.difficulty ?? 'fácil',
        photoUrl: seed.photoUrl ?? null,
      }),
    );
    await this.recipeIngredients.save(
      seed.ingredients.map((i) => {
        const ingredient = byName.get(i.name);
        if (!ingredient) {
          throw new Error(`Seed ingredient missing: ${i.name}`);
        }
        return this.recipeIngredients.create({
          recipeId: recipe.id,
          ingredientId: ingredient.id,
          quantity: i.quantity,
          unit: i.unit,
          optional: Boolean(i.optional),
        });
      }),
    );
    await this.steps.save(
      seed.steps.map((body, index) =>
        this.steps.create({ recipeId: recipe.id, position: index + 1, body }),
      ),
    );
    await this.search.upsertRecipe(recipe);
    return 'inserted';
  }

  private ingredientCache?: Map<string, Ingredient>;

  private async ingredientMap() {
    if (!this.ingredientCache) {
      const all = await this.ingredients.find();
      this.ingredientCache = new Map(all.map((i) => [i.name, i]));
    }
    return this.ingredientCache;
  }

  private async ensureSeedAuthor() {
    let author = await this.users.findOne({
      where: { firebaseUid: 'seed:dishtoday' },
    });
    if (!author) {
      author = await this.users.save(
        this.users.create({
          firebaseUid: 'seed:dishtoday',
          email: 'seed@dishtoday.app',
          displayName: 'DishToday',
          avatarUrl: null,
        }),
      );
      await this.prefs.save(
        this.prefs.create({ userId: author.id, allergies: [], diets: [] }),
      );
    }
    return author;
  }
}
