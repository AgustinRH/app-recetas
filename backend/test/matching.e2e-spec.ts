process.env.DB_TYPE = 'sqlite';
process.env.SQLITE_PATH = 'e2e.sqlite';
process.env.DEV_AUTH = 'true';
process.env.SEED_ON_START = 'true';
process.env.REDIS_URL = '';
process.env.TYPESENSE_HOST = '';
process.env.MINIO_ENDPOINT = '';
process.env.FIREBASE_PROJECT_ID = '';

import { Test } from '@nestjs/testing';
import { INestApplication, ValidationPipe } from '@nestjs/common';
import * as request from 'supertest';
import { AppModule } from '../src/app.module';
import { unlink } from 'fs/promises';

describe('Matching flow (e2e)', () => {
  let app: INestApplication;
  const auth = { Authorization: 'Bearer dev:demo@dishtoday.app' };

  beforeAll(async () => {
    try {
      await unlink('e2e.sqlite');
    } catch {
      /* missing is fine */
    }
    const moduleRef = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();
    app = moduleRef.createNestApplication();
    app.useGlobalPipes(
      new ValidationPipe({ whitelist: true, transform: true }),
    );
    await app.init();
  }, 30000);

  afterAll(async () => {
    await app.close();
    try {
      await unlink('e2e.sqlite');
    } catch {
      /* ignore */
    }
  });

  it('registers a user, fills the pantry and ranks recipes by match', async () => {
    const me = await request(app.getHttpServer()).post('/auth/sync').set(auth);
    expect(me.status).toBe(201);
    expect(me.body.email).toBe('demo@dishtoday.app');

    const ingredients = await request(app.getHttpServer())
      .get('/ingredients')
      .set(auth);
    expect(ingredients.status).toBe(200);
    expect(ingredients.body.length).toBeGreaterThanOrEqual(50);

    const wanted = [
      'Huevos',
      'Tomate',
      'Aceite de oliva',
      'Cebolla',
      'Sal',
      'Pan',
      'Ajo',
    ];
    const byName = new Map(
      ingredients.body.map((i: { id: string; name: string }) => [i.name, i.id]),
    );
    const stock: Record<string, { quantity: number; unit: string }> = {
      Huevos: { quantity: 12, unit: 'ud' },
      Tomate: { quantity: 6, unit: 'ud' },
      'Aceite de oliva': { quantity: 1, unit: 'l' },
      Cebolla: { quantity: 3, unit: 'ud' },
      Sal: { quantity: 500, unit: 'g' },
      Pan: { quantity: 1, unit: 'ud' },
      Ajo: { quantity: 1, unit: 'ud' },
    };
    for (const name of wanted) {
      const res = await request(app.getHttpServer())
        .post('/pantry')
        .set(auth)
        .send({ ingredientId: byName.get(name), ...stock[name] });
      expect(res.status).toBe(201);
    }

    const suggested = await request(app.getHttpServer())
      .get('/recipes/suggested')
      .set(auth);
    expect(suggested.status).toBe(200);
    expect(suggested.body[0].title).toBe('Pan con tomate');
    expect(suggested.body[0].matchPct).toBe(100);

    const tortilla = suggested.body.find(
      (r: { title: string }) => r.title === 'Tortilla de patatas',
    );
    expect(tortilla.matchPct).toBe(80);
    expect(tortilla.missingCount).toBe(1);

    const gazpacho = suggested.body.find(
      (r: { title: string }) => r.title === 'Gazpacho',
    );
    const detail = await request(app.getHttpServer())
      .get(`/recipes/${gazpacho.id}`)
      .set(auth);
    expect(detail.status).toBe(200);
    const missingNames = detail.body.missingIngredients
      .map((i: { name: string }) => i.name)
      .sort();
    expect(missingNames).toEqual(['Pepino', 'Pimiento']);

    // Cantidades: con 6 tomates el gazpacho (pide 6) va bien; con 2 ya no.
    const tomateItems = await request(app.getHttpServer())
      .get('/pantry')
      .set(auth);
    const tomate = tomateItems.body.find(
      (p: { ingredient: { name: string } }) => p.ingredient.name === 'Tomate',
    );
    const patched = await request(app.getHttpServer())
      .patch(`/pantry/${tomate.id}`)
      .set(auth)
      .send({ quantity: 2 });
    expect(patched.status).toBe(200);
    const detailLow = await request(app.getHttpServer())
      .get(`/recipes/${gazpacho.id}`)
      .set(auth);
    const tomateRow = detailLow.body.ingredients.find(
      (i: { name: string }) => i.name === 'Tomate',
    );
    expect(tomateRow.inPantry).toBe(true);
    expect(tomateRow.enough).toBe(false);
    expect(tomateRow.pantryQuantity).toBe(2);
    expect(
      detailLow.body.missingIngredients
        .map((i: { name: string }) => i.name)
        .sort(),
    ).toEqual(['Pepino', 'Pimiento', 'Tomate']);
    expect(detailLow.body.matchPct).toBe(50);

    // Volver a añadir el mismo ingrediente actualiza la cantidad (no da error).
    const readd = await request(app.getHttpServer())
      .post('/pantry')
      .set(auth)
      .send({ ingredientId: byName.get('Tomate'), quantity: 6, unit: 'ud' });
    expect(readd.status).toBe(201);
    expect(readd.body.quantity).toBe(6);

    const like = await request(app.getHttpServer())
      .post(`/recipes/${detail.body.id}/likes`)
      .set(auth);
    expect(like.status).toBe(201);

    const comment = await request(app.getHttpServer())
      .post(`/recipes/${detail.body.id}/comments`)
      .set(auth)
      .send({ body: 'Falta pepino en mi despensa' });
    expect(comment.status).toBe(201);

    const save = await request(app.getHttpServer())
      .post(`/recipes/${detail.body.id}/saves`)
      .set(auth);
    expect(save.status).toBe(201);

    const feed = await request(app.getHttpServer()).get('/feed').set(auth);
    expect(feed.status).toBe(200);
    expect(feed.body.items.length).toBeGreaterThan(0);
  });
});
