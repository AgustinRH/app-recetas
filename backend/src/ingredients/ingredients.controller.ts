import { Controller, Get, Query } from '@nestjs/common';
import { IngredientsService } from './ingredients.service';

@Controller('ingredients')
export class IngredientsController {
  constructor(private readonly ingredients: IngredientsService) {}

  @Get()
  list(@Query('q') q?: string, @Query('category') category?: string) {
    return this.ingredients.findAll(q, category);
  }
}
