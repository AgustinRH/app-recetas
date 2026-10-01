/**
 * Añade al catálogo los ingredientes de `seed-data.ts` que falten en la BD.
 * No borra ni modifica nada más.
 *
 * En producción (dentro del contenedor api):
 *   docker compose --env-file ../.env exec api node dist/scripts/sync-ingredients.js
 * En local:
 *   npm run sync:ingredients
 */
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { SeedService } from '../seed/seed.service';

async function main() {
  process.env.SEED_ON_START = 'false';
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  try {
    const added = await app.get(SeedService).addMissingIngredients();
    console.log(`Ingredientes añadidos: ${added}`);
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
