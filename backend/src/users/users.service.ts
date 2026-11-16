import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { InjectRepository } from '@nestjs/typeorm';
import { getAuth } from 'firebase-admin/auth';
import { DataSource, Repository } from 'typeorm';
import { isAdminEmail } from '../auth/admin-email';
import { cookingStreak, todayInMadrid } from '../common/madrid-date';
import { awardBadges, BADGE_CATALOG, earnedFromActivity } from './badges';
import { RedisService } from '../redis/redis.service';
import { SearchService } from '../search/search.service';
import { User } from '../entities/user.entity';
import { UserPreferences } from '../entities/user-preferences.entity';
import { Recipe } from '../entities/recipe.entity';
import { Like } from '../entities/like.entity';
import { SavedRecipe } from '../entities/saved-recipe.entity';
import { PantryItem } from '../entities/pantry-item.entity';

@Injectable()
export class UsersService {
  constructor(
    private readonly config: ConfigService,
    private readonly dataSource: DataSource,
    private readonly search: SearchService,
    private readonly redis: RedisService,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(UserPreferences)
    private readonly prefs: Repository<UserPreferences>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    @InjectRepository(Like) private readonly likes: Repository<Like>,
    @InjectRepository(SavedRecipe)
    private readonly saves: Repository<SavedRecipe>,
    @InjectRepository(PantryItem)
    private readonly pantry: Repository<PantryItem>,
  ) {}

  /** Resumen de actividad para la pantalla de perfil. */
  async stats(userId: string) {
    const [
      recipesCount,
      likesReceived,
      savedCount,
      pantryCount,
      cuisines,
      cookedRows,
      dayRows,
      followRows,
    ] = await Promise.all([
      this.recipes.count({ where: { authorId: userId } }),
      this.likes
        .createQueryBuilder('l')
        .innerJoin('l.recipe', 'r')
        .where('r.authorId = :userId', { userId })
        .getCount(),
      this.saves.count({ where: { userId } }),
      this.pantry.count({ where: { userId } }),
      this.recipes
        .createQueryBuilder('r')
        .select('r.cuisine', 'cuisine')
        .addSelect('COUNT(*)', 'count')
        .where('r.authorId = :userId', { userId })
        .groupBy('r.cuisine')
        .orderBy('count', 'DESC')
        .limit(3)
        .getRawMany<{ cuisine: string; count: string }>(),
      this.dataSource.query<{ count: string }[]>(
        `SELECT COUNT(*)::int AS count FROM cooked_recipes WHERE "userId" = $1`,
        [userId],
      ),
      this.dataSource.query<{ day: string }[]>(
        `SELECT DISTINCT "cookedOn"::text AS day FROM cooked_recipes WHERE "userId" = $1`,
        [userId],
      ),
      this.dataSource.query<{ followers: string; following: string }[]>(
        `SELECT
             (SELECT COUNT(*)::int FROM follows WHERE "followingId" = $1) AS followers,
             (SELECT COUNT(*)::int FROM follows WHERE "followerId" = $1) AS following`,
        [userId],
      ),
    ]);
    const today = todayInMadrid();
    const days = dayRows.map((row) => String(row.day).slice(0, 10));
    const cookedCount = Number(cookedRows[0]?.count ?? 0);
    const { streak, bestStreak } = cookingStreak(days, today);
    await awardBadges(
      this.dataSource,
      userId,
      earnedFromActivity({
        cookedCount,
        bestStreak,
        recipesCount,
        pantryCount,
      }),
    );
    const badgeRows = await this.dataSource.query<{ code: string }[]>(
      `SELECT code FROM user_badges WHERE "userId" = $1`,
      [userId],
    );
    const earned = new Set(badgeRows.map((row) => row.code));
    return {
      recipesCount,
      likesReceived,
      savedCount,
      pantryCount,
      cookedCount,
      cookedToday: days.includes(today),
      streak,
      bestStreak,
      followersCount: Number(followRows[0]?.followers ?? 0),
      followingCount: Number(followRows[0]?.following ?? 0),
      badges: BADGE_CATALOG.map((badge) => ({
        ...badge,
        earned: earned.has(badge.code),
      })),
      topCuisines: cuisines.map((c) => c.cuisine),
    };
  }

  async upsertFromAuth(input: {
    firebaseUid: string;
    email?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  }) {
    let user = await this.users.findOne({
      where: { firebaseUid: input.firebaseUid },
      relations: { preferences: true },
    });
    if (!user) {
      user = this.users.create({
        firebaseUid: input.firebaseUid,
        email: input.email ?? null,
        displayName: input.displayName || input.email?.split('@')[0] || 'Chef',
        avatarUrl: input.avatarUrl ?? null,
      });
      user = await this.users.save(user);
      const preferences = this.prefs.create({
        userId: user.id,
        allergies: [],
        diets: [],
      });
      await this.prefs.save(preferences);
      user.preferences = preferences;
    }
    if (input.email) user.email = input.email;
    if (input.avatarUrl && !user.avatarUrl) user.avatarUrl = input.avatarUrl;
    if (input.displayName && user.displayName === 'Chef') {
      user.displayName = input.displayName;
    }
    user.isAdmin = isAdminEmail(
      user.email,
      this.config.get<string>('ADMIN_EMAILS'),
    );
    return this.users.save(user);
  }

  findById(id: string) {
    return this.users.findOne({
      where: { id },
      relations: { preferences: true },
    });
  }

  async updateProfile(
    userId: string,
    data: { displayName?: string; avatarUrl?: string | null },
  ) {
    const user = await this.findById(userId);
    if (!user) return null;
    if (data.displayName !== undefined) user.displayName = data.displayName;
    if (data.avatarUrl !== undefined) user.avatarUrl = data.avatarUrl;
    return this.users.save(user);
  }

  async updatePreferences(
    userId: string,
    data: { allergies?: string[]; diets?: string[] },
  ) {
    let prefs = await this.prefs.findOne({ where: { userId } });
    if (!prefs) {
      prefs = this.prefs.create({
        userId,
        allergies: data.allergies ?? [],
        diets: data.diets ?? [],
      });
    } else {
      if (data.allergies) prefs.allergies = data.allergies;
      if (data.diets) prefs.diets = data.diets;
    }
    return this.prefs.save(prefs);
  }

  /**
   * Borra la cuenta y lo que cuelga de ella: despensa, plan, compra, recetas
   * publicadas y el acceso en Firebase. Las recetas de otras personas se quedan.
   */
  async deleteAccount(user: User) {
    const owned = await this.recipes.find({
      where: { authorId: user.id },
      select: { id: true },
    });
    const ids = owned.map((recipe) => recipe.id);
    await deleteFirebaseUser(user.firebaseUid);
    await this.dataSource.transaction(async (manager) => {
      if (ids.length) {
        for (const table of [
          'comments',
          'likes',
          'saved_recipes',
          'recipe_steps',
          'recipe_ingredients',
          'recipe_reports',
          'meal_slots',
          'cooked_recipes',
        ]) {
          await manager.query(
            `DELETE FROM ${table} WHERE "recipeId" = ANY($1::uuid[])`,
            [ids],
          );
        }
        await manager.query(
          `UPDATE shopping_items SET "recipeId" = NULL WHERE "recipeId" = ANY($1::text[])`,
          [ids],
        );
        await manager.query(`DELETE FROM recipes WHERE id = ANY($1::uuid[])`, [
          ids,
        ]);
      }
      await manager.query(`DELETE FROM users WHERE id = $1`, [user.id]);
    });
    await Promise.all(ids.map((id) => this.search.removeRecipe(id)));
    await this.redis.del('feed:first-page');
    return { ok: true };
  }

  async setFollow(followerId: string, followingId: string, follow: boolean) {
    if (followerId === followingId) {
      throw new BadRequestException('No puedes seguirte a ti mismo');
    }
    const target = await this.users.findOne({ where: { id: followingId } });
    if (!target || target.banned)
      throw new NotFoundException('Usuario no encontrado');
    if (follow) {
      await this.dataSource.query(
        `INSERT INTO follows (id, "followerId", "followingId")
         VALUES (uuid_generate_v4(), $1, $2)
         ON CONFLICT ("followerId", "followingId") DO NOTHING`,
        [followerId, followingId],
      );
    } else {
      await this.dataSource.query(
        `DELETE FROM follows WHERE "followerId" = $1 AND "followingId" = $2`,
        [followerId, followingId],
      );
    }
    return { following: follow };
  }

  async isFollowing(followerId: string | null, followingId: string) {
    if (!followerId || followerId === followingId) return false;
    const rows = await this.dataSource.query<{ ok: boolean }[]>(
      `SELECT EXISTS (
         SELECT 1 FROM follows WHERE "followerId" = $1 AND "followingId" = $2
       ) AS ok`,
      [followerId, followingId],
    );
    return Boolean(rows[0]?.ok);
  }

  toPublic(user: User) {
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      isAdmin: Boolean(user.isAdmin),
      createdAt: user.createdAt,
      preferences: user.preferences
        ? {
            allergies: user.preferences.allergies ?? [],
            diets: user.preferences.diets ?? [],
          }
        : { allergies: [], diets: [] },
    };
  }
}

/** Quita el acceso en Firebase. Un uid de semilla no tiene cuenta allí. */
async function deleteFirebaseUser(uid: string) {
  if (uid.startsWith('seed:') || uid.startsWith('dev:')) return;
  try {
    await getAuth().deleteUser(uid);
  } catch (error) {
    const code = (error as { code?: string }).code;
    if (code === 'auth/user-not-found') return;
    throw error;
  }
}
