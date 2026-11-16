/**
 * Inserta el catálogo de `src/seed/bulk-recipes.json` y descarga una foto
 * libre de Wikimedia Commons para cada receta que aún no tenga.
 *
 *   docker compose --env-file ../.env exec api node dist/scripts/sync-recipes.js
 */
import { mkdir, writeFile } from 'fs/promises';
import { readFileSync } from 'fs';
import { join } from 'path';
import { NestFactory } from '@nestjs/core';
import { AppModule } from '../app.module';
import { RecipeSeed } from '../seed/seed-data';
import { SeedService } from '../seed/seed.service';

const UA = 'DishTodaySeed/1.0 (https://dishtoday.eu; catalogo de recetas)';

type BulkRecipe = RecipeSeed & { photoQuery?: string };

const EXTRA_PHOTOS: Record<string, string> = {
  'Tortilla de patatas': 'spanish potato omelette',
  'Ensalada mixta': 'mixed green salad',
  Gazpacho: 'gazpacho soup',
  'Pasta al pesto': 'pesto pasta',
  'Arroz con pollo': 'chicken rice',
  'Huevos revueltos': 'scrambled eggs',
  Guacamole: 'guacamole',
  'Lentejas estofadas': 'lentil stew',
  'Pan con tomate': 'pan con tomate',
  'Yogur con fruta': 'yogurt fruit bowl',
};

function sleep(ms: number) {
  return new Promise((resolve) => setTimeout(resolve, ms));
}

function slug(title: string) {
  return title
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-|-$/g, '')
    .slice(0, 80);
}

function plain(html?: string) {
  return (html ?? '')
    .replace(/<[^>]+>/g, '')
    .replace(/&amp;/g, '&')
    .replace(/&quot;/g, '"')
    .replace(/\s+/g, ' ')
    .trim();
}

function licenseOk(name: string) {
  const n = name.toLowerCase();
  if (n.includes('noncommercial') || /(^|[^a-z])nc([^a-z]|$)/.test(n))
    return false;
  return (
    n.includes('cc by') || n.includes('cc0') || n.includes('public domain')
  );
}

function titleOk(title: string) {
  return !/icon|logo|flag|map|diagram|chart|coat of arms|stamp|drawing|illustration|portrait|poster|menu|package|advert/i.test(
    title,
  );
}

async function commonsPhoto(query: string) {
  const url = new URL('https://commons.wikimedia.org/w/api.php');
  url.searchParams.set('action', 'query');
  url.searchParams.set('format', 'json');
  url.searchParams.set('generator', 'search');
  url.searchParams.set('gsrsearch', `filetype:bitmap ${query}`);
  url.searchParams.set('gsrnamespace', '6');
  url.searchParams.set('gsrlimit', '8');
  url.searchParams.set('prop', 'imageinfo');
  url.searchParams.set('iiprop', 'url|mime|extmetadata');
  url.searchParams.set('iiurlwidth', '900');
  const res = await fetch(url, { headers: { 'User-Agent': UA } });
  if (!res.ok) return null;
  const data = (await res.json()) as {
    query?: {
      pages?: Record<
        string,
        {
          title?: string;
          imageinfo?: {
            thumburl?: string;
            mime?: string;
            extmetadata?: Record<string, { value?: string }>;
          }[];
        }
      >;
    };
  };
  const pages = Object.values(data.query?.pages ?? {});
  for (const page of pages) {
    const info = page.imageinfo?.[0];
    const mime = info?.mime ?? '';
    const license = plain(info?.extmetadata?.LicenseShortName?.value);
    if (!info?.thumburl || !titleOk(page.title ?? '')) continue;
    if (!mime.startsWith('image/jpeg') && !mime.startsWith('image/png'))
      continue;
    if (!licenseOk(license)) continue;
    const img = await fetch(info.thumburl, { headers: { 'User-Agent': UA } });
    if (!img.ok) continue;
    const buffer = Buffer.from(await img.arrayBuffer());
    const jpeg = buffer[0] === 0xff && buffer[1] === 0xd8;
    const png = buffer[0] === 0x89 && buffer[1] === 0x50;
    if ((!jpeg && !png) || buffer.length < 12_000) continue;
    const artist =
      plain(info.extmetadata?.Artist?.value) || 'autor desconocido';
    const credit = `${artist}, ${license}, Wikimedia Commons`;
    return { buffer, credit, ext: jpeg ? 'jpg' : 'png' };
  }
  return null;
}

async function main() {
  process.env.SEED_ON_START = 'false';
  const app = await NestFactory.createApplicationContext(AppModule, {
    logger: ['error', 'warn', 'log'],
  });
  const seed = app.get(SeedService);
  const publicBase = (
    process.env.PUBLIC_BASE_URL ?? 'http://localhost:3000'
  ).replace(/\/$/, '');
  const dir = join(process.cwd(), 'uploads', 'recipes');
  await mkdir(dir, { recursive: true });
  const bulk = JSON.parse(
    readFileSync(join(process.cwd(), 'src/seed/bulk-recipes.json'), 'utf8'),
  ) as BulkRecipe[];

  let inserted = 0;
  let updated = 0;
  let skipped = 0;
  let photos = 0;
  let missed = 0;

  async function takePhoto(query: string, title: string) {
    const photo = await commonsPhoto(query);
    await sleep(250);
    if (!photo) {
      missed += 1;
      return { photoUrl: null as string | null, credit: null as string | null };
    }
    const file = `seed-${slug(title)}.${photo.ext}`;
    await writeFile(join(dir, file), photo.buffer);
    photos += 1;
    return {
      photoUrl: `${publicBase}/uploads/recipes/${file}`,
      credit: photo.credit,
    };
  }

  try {
    for (let i = 0; i < bulk.length; i++) {
      const recipe = bulk[i];
      const state = await seed.seedRecipeState(recipe.title);
      if (state === 'ready') {
        skipped += 1;
        if ((i + 1) % 25 === 0) {
          console.log(
            `${i + 1}/${bulk.length} insertadas=${inserted} fotos=${photos} sin_foto=${missed}`,
          );
        }
        continue;
      }
      let photoUrl: string | null = null;
      let description = recipe.description;
      if (recipe.photoQuery) {
        const photo = await takePhoto(recipe.photoQuery, recipe.title);
        photoUrl = photo.photoUrl;
        if (photo.credit)
          description = `${description}\n\nFoto: ${photo.credit}.`;
      }
      const status = await seed.addCatalogRecipe({
        ...recipe,
        description,
        photoUrl,
      });
      if (status === 'inserted') inserted += 1;
      else if (status === 'updated') updated += 1;
      else skipped += 1;
      if ((i + 1) % 25 === 0) {
        console.log(
          `${i + 1}/${bulk.length} insertadas=${inserted} fotos=${photos} sin_foto=${missed}`,
        );
      }
    }
    for (const [title, query] of Object.entries(EXTRA_PHOTOS)) {
      if ((await seed.seedRecipeState(title)) !== 'needs-photo') continue;
      const photo = await takePhoto(query, title);
      if (!photo.photoUrl || !photo.credit) continue;
      const status = await seed.addCatalogRecipe({
        title,
        description: `Foto: ${photo.credit}.`,
        prepMinutes: 1,
        cuisine: 'Española',
        dietTags: [],
        calories: 0,
        ingredients: [],
        steps: [],
        photoUrl: photo.photoUrl,
      });
      if (status === 'updated') updated += 1;
    }
    console.log(
      JSON.stringify({
        inserted,
        updated,
        skipped,
        photos,
        missed,
        total: bulk.length,
      }),
    );
  } finally {
    await app.close();
  }
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
