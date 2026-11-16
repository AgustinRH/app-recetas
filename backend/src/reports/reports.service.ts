import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { Recipe } from '../entities/recipe.entity';
import { REPORT_REASONS, RecipeReport } from '../entities/recipe-report.entity';

@Injectable()
export class ReportsService {
  constructor(
    @InjectRepository(RecipeReport)
    private readonly reports: Repository<RecipeReport>,
    @InjectRepository(Recipe) private readonly recipes: Repository<Recipe>,
  ) {}

  async create(userId: string, recipeId: string, reason: string, note: string) {
    if (!REPORT_REASONS.includes(reason as (typeof REPORT_REASONS)[number])) {
      throw new BadRequestException('Motivo no válido');
    }
    const recipe = await this.recipes.findOne({ where: { id: recipeId } });
    if (!recipe) throw new NotFoundException('Receta no encontrada');
    if (recipe.authorId === userId) {
      throw new BadRequestException('No puedes denunciar tu propia receta');
    }
    const existing = await this.reports.findOne({
      where: { userId, recipeId },
    });
    if (existing?.status === 'open') {
      throw new ConflictException('Ya has denunciado esta receta');
    }
    if (existing) {
      existing.status = 'open';
      existing.reason = reason;
      existing.note = note.trim();
      existing.createdAt = new Date();
      const saved = await this.reports.save(existing);
      return { id: saved.id, status: saved.status };
    }
    const saved = await this.reports.save(
      this.reports.create({
        userId,
        recipeId,
        reason,
        note: note.trim(),
        status: 'open',
      }),
    );
    return { id: saved.id, status: saved.status };
  }
}
