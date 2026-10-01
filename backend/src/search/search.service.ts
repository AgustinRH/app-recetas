import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Typesense from 'typesense';
import { Ingredient } from '../entities/ingredient.entity';
import { Recipe } from '../entities/recipe.entity';

@Injectable()
export class SearchService implements OnModuleInit {
  private readonly logger = new Logger(SearchService.name);
  private client: any = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const host = this.config.get<string>('TYPESENSE_HOST');
    const apiKey = this.config.get<string>('TYPESENSE_API_KEY');
    if (!host || !apiKey) {
      this.logger.warn('Typesense disabled (missing host/api key)');
      return;
    }
    this.client = new Typesense.Client({
      nodes: [
        {
          host,
          port: Number(this.config.get('TYPESENSE_PORT') ?? 8108),
          protocol: this.config.get('TYPESENSE_PROTOCOL') ?? 'http',
        },
      ],
      apiKey,
      connectionTimeoutSeconds: 2,
    });
    this.ensureCollections().catch((err) =>
      this.logger.warn(`Typesense collections: ${err.message}`),
    );
  }

  isReady() {
    return Boolean(this.client);
  }

  private async ensureCollections() {
    if (!this.client) return;
    const collections = await this.client.collections().retrieve();
    const names = collections.map((c) => c.name);
    if (!names.includes('ingredients')) {
      await this.client.collections().create({
        name: 'ingredients',
        fields: [
          { name: 'name', type: 'string' },
          { name: 'category', type: 'string', facet: true },
          { name: 'aliases', type: 'string[]', optional: true },
        ],
      });
    }
    if (!names.includes('recipes')) {
      await this.client.collections().create({
        name: 'recipes',
        fields: [
          { name: 'title', type: 'string' },
          { name: 'description', type: 'string', optional: true },
          { name: 'cuisine', type: 'string', facet: true },
          { name: 'diet_tags', type: 'string[]', facet: true, optional: true },
          { name: 'prep_minutes', type: 'int32', facet: true },
        ],
      });
    }
  }

  async upsertIngredient(ingredient: Ingredient) {
    if (!this.client) return;
    try {
      await this.client.collections('ingredients').documents().upsert({
        id: ingredient.id,
        name: ingredient.name,
        category: ingredient.category,
        aliases: ingredient.aliases ?? [],
      });
    } catch (err) {
      this.logger.warn(`Index ingredient failed: ${(err as Error).message}`);
    }
  }

  async upsertRecipe(recipe: Recipe) {
    if (!this.client) return;
    try {
      await this.client.collections('recipes').documents().upsert({
        id: recipe.id,
        title: recipe.title,
        description: recipe.description ?? '',
        cuisine: recipe.cuisine,
        diet_tags: recipe.dietTags ?? [],
        prep_minutes: recipe.prepMinutes,
      });
    } catch (err) {
      this.logger.warn(`Index recipe failed: ${(err as Error).message}`);
    }
  }

  async removeRecipe(id: string) {
    if (!this.client) return;
    try {
      await this.client.collections('recipes').documents(id).delete();
    } catch {
      /* the document may already be gone */
    }
  }

  async searchIngredients(q: string) {
    if (!this.client) return [];
    try {
      const result = await this.client
        .collections('ingredients')
        .documents()
        .search({ q, query_by: 'name,aliases', per_page: 15 });
      return (result.hits ?? []).map((h) => h.document as Ingredient);
    } catch {
      return [];
    }
  }

  async searchRecipes(q: string) {
    if (!this.client) return [] as string[];
    try {
      const result = await this.client
        .collections('recipes')
        .documents()
        .search({ q, query_by: 'title,description,cuisine', per_page: 30 });
      return (result.hits ?? []).map((h) => String((h.document as { id: string }).id));
    } catch {
      return [];
    }
  }
}
