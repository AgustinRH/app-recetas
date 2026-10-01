import { Body, Controller, Get, Post, Query } from '@nestjs/common';
import { IsOptional, IsString, MaxLength, MinLength } from 'class-validator';
import { Transform } from 'class-transformer';
import { IngredientsService } from './ingredients.service';

const trim = () =>
  Transform(({ value }) => (typeof value === 'string' ? value.trim() : value));

class CreateIngredientDto {
  @trim()
  @IsString()
  @MinLength(2)
  @MaxLength(60)
  name: string;

  @IsOptional()
  @trim()
  @IsString()
  @MaxLength(40)
  category?: string;
}

@Controller('ingredients')
export class IngredientsController {
  constructor(private readonly ingredients: IngredientsService) {}

  @Get()
  list(
    @Query('q') q?: string,
    @Query('category') category?: string,
    @Query('limit') limit?: string,
  ) {
    return this.ingredients.findAll(q, category, limit ? Number(limit) : undefined);
  }

  @Get('categories')
  categories() {
    return this.ingredients.categories();
  }

  /**
   * Crea un ingrediente que no está en el catálogo (p. ej. "Dorada").
   * Si ya existe uno con ese nombre o alias, devuelve el existente.
   */
  @Post()
  create(@Body() body: CreateIngredientDto) {
    return this.ingredients.createOrGet(body.name, body.category);
  }
}
