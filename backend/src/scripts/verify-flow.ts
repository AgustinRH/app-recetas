import { NestFactory } from '@nestjs/core';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import { AppModule } from '../app.module';
import { RecipesService } from '../recipes/recipes.service';
import { UsersService } from '../users/users.service';
import { PantryService } from '../pantry/pantry.service';
import { IngredientsService } from '../ingredients/ingredients.service';

async function verify() {
  process.env.DB_TYPE = process.env.DB_TYPE || 'sqlite';
  process.env.DEV_AUTH = 'true';
  process.env.SEED_ON_START = 'true';
  const app: INestApplication = await NestFactory.create(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, transform: true }));
  await app.init();

  const users = app.get(UsersService);
  const pantry = app.get(PantryService);
  const ingredients = app.get(IngredientsService);
  const recipes = app.get(RecipesService);

  const user = await users.upsertFromAuth({
    firebaseUid: 'dev:verify@dishtoday.app',
    email: 'verify@dishtoday.app',
    displayName: 'verify',
  });
  const catalog = await ingredients.findAll();
  const wanted = [
    'Huevos',
    'Tomate',
    'Aceite de oliva',
    'Cebolla',
    'Sal',
    'Pan',
    'Ajo',
  ];
  const byName = new Map(catalog.map((i) => [i.name, i.id]));
  const existing = await pantry.list(user.id);
  const have = new Set(existing.map((p) => p.ingredientId));
  for (const name of wanted) {
    const id = byName.get(name);
    if (typeof id !== 'string') throw new Error(`Missing seed ingredient ${name}`);
    if (!have.has(id)) {
      await pantry.create(user.id, { ingredientId: id, quantity: 1, unit: 'ud' });
    }
  }

  const suggested = await recipes.suggested(user.id, {});
  const top = suggested[0];
  if (top.title !== 'Pan con tomate' || top.matchPct !== 100) {
    throw new Error(
      `Expected Pan con tomate at 100%, got ${top.title} (${top.matchPct})`,
    );
  }
  const tortilla = suggested.find((r) => r.title === 'Tortilla de patatas');
  if (!tortilla || tortilla.matchPct !== 80 || tortilla.missingCount !== 1) {
    throw new Error(`Tortilla match unexpected: ${JSON.stringify(tortilla)}`);
  }
  const gazpachoCard = suggested.find((r) => r.title === 'Gazpacho');
  const detail = await recipes.findDetail(gazpachoCard!.id, user.id);
  const missing = detail.missingIngredients.map((i) => i.name).sort();
  if (missing.join(',') !== 'Pepino,Pimiento') {
    throw new Error(`Gazpacho missing ${missing.join(',')}`);
  }

  await recipes.toggleLike(user.id, detail.id, true);
  await recipes.addComment(user.id, detail.id, 'Verificado');
  await recipes.toggleSave(user.id, detail.id, true);
  const feed = await recipes.feed(user.id);
  if (!feed.items.length) throw new Error('Empty feed');

  console.log('OK matching flow');
  console.log(
    suggested
      .slice(0, 5)
      .map((r) => `${r.matchPct}% ${r.title} (faltan ${r.missingCount})`)
      .join('\n'),
  );
  await app.close();
}

verify().catch((err) => {
  console.error(err);
  process.exit(1);
});
