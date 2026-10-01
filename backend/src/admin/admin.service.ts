import { BadRequestException, Injectable, NotFoundException } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { DataSource, ILike, Repository } from 'typeorm';
import { Comment } from '../entities/comment.entity';
import { Recipe } from '../entities/recipe.entity';
import { REPORT_REASON_LABELS, RecipeReport } from '../entities/recipe-report.entity';
import { User } from '../entities/user.entity';
import { RedisService } from '../redis/redis.service';
import { SearchService } from '../search/search.service';

const FEED_CACHE_KEY = 'feed:first-page';

@Injectable()
export class AdminService {
  constructor(
    private readonly dataSource: DataSource,
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
    @InjectRepository(Comment) private readonly comments: Repository<Comment>,
    @InjectRepository(RecipeReport) private readonly reports: Repository<RecipeReport>,
    private readonly search: SearchService,
    private readonly redis: RedisService,
  ) {}

  async summary() {
    const [users, recipes, comments, banned, openReports] = await Promise.all([
      this.users.count(),
      this.recipes.count(),
      this.comments.count(),
      this.users.count({ where: { banned: true } }),
      this.reports.count({ where: { status: 'open' } }),
    ]);
    return { users, recipes, comments, banned, openReports };
  }

  async listUsers(q?: string) {
    const where = q
      ? [{ email: ILike(`%${q}%`) }, { displayName: ILike(`%${q}%`) }]
      : {};
    const rows = await this.users.find({
      where,
      order: { createdAt: 'DESC' },
      take: 40,
    });
    const counts = new Map<string, number>();
    if (rows.length) {
      const raw = await this.recipes
        .createQueryBuilder('r')
        .select('r.authorId', 'authorId')
        .addSelect('COUNT(*)', 'count')
        .where('r.authorId IN (:...ids)', { ids: rows.map((u) => u.id) })
        .groupBy('r.authorId')
        .getRawMany<{ authorId: string; count: string }>();
      for (const row of raw) counts.set(row.authorId, Number(row.count));
    }
    return rows.map((user) => ({
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      isAdmin: user.isAdmin,
      banned: user.banned,
      createdAt: user.createdAt,
      recipesCount: counts.get(user.id) ?? 0,
    }));
  }

  async setBanned(actorId: string, userId: string, banned: boolean) {
    if (actorId === userId) {
      throw new BadRequestException('No puedes suspender tu propia cuenta');
    }
    const user = await this.users.findOne({ where: { id: userId } });
    if (!user) throw new NotFoundException('Usuario no encontrado');
    if (user.isAdmin) {
      throw new BadRequestException('No se puede suspender a otro administrador');
    }
    user.banned = banned;
    await this.users.save(user);
    return { id: user.id, banned: user.banned };
  }

  async listRecipes(q?: string) {
    const qb = this.recipes
      .createQueryBuilder('r')
      .leftJoin('r.author', 'author')
      .select([
        'r.id',
        'r.title',
        'r.cuisine',
        'r.createdAt',
        'author.displayName',
        'author.email',
      ])
      .orderBy('r.createdAt', 'DESC')
      .take(40);
    if (q) qb.where('r.title ILIKE :q', { q: `%${q}%` });
    const rows = await qb.getMany();
    return rows.map((recipe) => ({
      id: recipe.id,
      title: recipe.title,
      cuisine: recipe.cuisine,
      createdAt: recipe.createdAt,
      authorName: recipe.author?.displayName ?? '',
      authorEmail: recipe.author?.email ?? null,
    }));
  }

  async deleteRecipe(id: string) {
    const recipe = await this.recipes.findOne({ where: { id } });
    if (!recipe) throw new NotFoundException('Receta no encontrada');
    await this.dataSource.transaction(async (manager) => {
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
        await manager.query(`DELETE FROM ${table} WHERE "recipeId" = $1`, [id]);
      }
      await manager.query(`UPDATE shopping_items SET "recipeId" = NULL WHERE "recipeId" = $1`, [id]);
      await manager.query(`DELETE FROM recipes WHERE id = $1`, [id]);
    });
    await this.search.removeRecipe(id);
    await this.redis.del(FEED_CACHE_KEY);
    return { ok: true };
  }

  async listComments(q?: string) {
    const qb = this.comments
      .createQueryBuilder('c')
      .leftJoin('c.user', 'author')
      .leftJoin('c.recipe', 'recipe')
      .select([
        'c.id',
        'c.body',
        'c.createdAt',
        'c.recipeId',
        'author.displayName',
        'recipe.title',
      ])
      .orderBy('c.createdAt', 'DESC')
      .take(40);
    if (q) qb.where('c.body ILIKE :q', { q: `%${q}%` });
    const rows = await qb.getMany();
    return rows.map((comment) => ({
      id: comment.id,
      body: comment.body,
      recipeId: comment.recipeId,
      recipeTitle: comment.recipe?.title ?? '',
      authorName: comment.user?.displayName ?? '',
      createdAt: comment.createdAt,
    }));
  }

  async deleteComment(id: string) {
    const result = await this.comments.delete(id);
    if (!result.affected) throw new NotFoundException('Comentario no encontrado');
    return { ok: true };
  }

  async listReports(q?: string) {
    const qb = this.reports
      .createQueryBuilder('report')
      .leftJoinAndSelect('report.user', 'user')
      .leftJoinAndSelect('report.recipe', 'recipe')
      .where('report.status = :status', { status: 'open' })
      .orderBy('report.createdAt', 'DESC')
      .take(50);
    if (q) {
      qb.andWhere(
        '(recipe.title ILIKE :q OR report.note ILIKE :q OR user.email ILIKE :q OR user.displayName ILIKE :q)',
        { q: `%${q}%` },
      );
    }
    const rows = await qb.getMany();
    return rows.map((report) => ({
      id: report.id,
      reason: report.reason,
      reasonLabel:
        REPORT_REASON_LABELS[report.reason as keyof typeof REPORT_REASON_LABELS] ?? report.reason,
      note: report.note,
      status: report.status,
      createdAt: report.createdAt,
      recipeId: report.recipeId,
      recipeTitle: report.recipe?.title ?? '',
      reporterName: report.user?.displayName ?? '',
      reporterEmail: report.user?.email ?? null,
    }));
  }

  async dismissReport(id: string) {
    const report = await this.reports.findOne({ where: { id } });
    if (!report) throw new NotFoundException('Denuncia no encontrada');
    report.status = 'dismissed';
    await this.reports.save(report);
    return { id: report.id, status: report.status };
  }
}
