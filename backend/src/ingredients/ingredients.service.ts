import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository, ILike, Like } from 'typeorm';
import { Ingredient } from '../entities/ingredient.entity';
import { SearchService } from '../search/search.service';

@Injectable()
export class IngredientsService {
  constructor(
    @InjectRepository(Ingredient)
    private readonly ingredients: Repository<Ingredient>,
    private readonly searchService: SearchService,
  ) {}

  async findAll(q?: string, category?: string) {
    if (q && this.searchService.isReady()) {
      const hits = await this.searchService.searchIngredients(q);
      if (hits.length) {
        return hits.filter((h) => !category || h.category === category);
      }
    }
    const where: Record<string, unknown> = {};
    if (category) where.category = category;
    if (!q) {
      return this.ingredients.find({ where, order: { name: 'ASC' }, take: 80 });
    }
    const driver = this.ingredients.manager.connection.options.type;
    const nameFilter =
      driver === 'postgres' ? ILike(`%${q}%`) : Like(`%${q}%`);
    return this.ingredients.find({
      where: { ...where, name: nameFilter },
      order: { name: 'ASC' },
      take: 20,
    });
  }

  findById(id: string) {
    return this.ingredients.findOne({ where: { id } });
  }
}
