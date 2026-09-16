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
import { INGREDIENT_SEEDS, RECIPE_SEEDS } from './seed-data';

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

  async run() {
    const count = await this.ingredients.count();
    if (count > 0) {
      this.logger.log('Seed skipped (ingredients already present)');
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
}
