import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Param,
  Post,
  Query,
  UploadedFile,
  UseInterceptors,
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import {
  IsArray,
  IsBoolean,
  IsInt,
  IsNumber,
  IsOptional,
  IsString,
  IsUUID,
  Min,
  ValidateNested,
} from 'class-validator';
import { Type } from 'class-transformer';
import { memoryStorage } from 'multer';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { RecipesService } from './recipes.service';

class RecipeIngredientDto {
  @IsUUID()
  ingredientId: string;

  @IsOptional()
  @IsNumber()
  quantity?: number;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsBoolean()
  optional?: boolean;
}

class CreateRecipeDto {
  @IsString()
  title: string;

  @IsOptional()
  @IsString()
  description?: string;

  @IsOptional()
  @IsInt()
  @Min(1)
  prepMinutes?: number;

  @IsOptional()
  @IsString()
  cuisine?: string;

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  dietTags?: string[];

  @IsOptional()
  @IsNumber()
  calories?: number;

  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RecipeIngredientDto)
  ingredients: RecipeIngredientDto[];

  @IsArray()
  @IsString({ each: true })
  steps: string[];
}

@Controller()
export class RecipesController {
  constructor(private readonly recipes: RecipesService) {}

  @Get('recipes/suggested')
  suggested(
    @CurrentUser() user: User,
    @Query('maxMinutes') maxMinutes?: string,
    @Query('cuisine') cuisine?: string,
    @Query('diet') diet?: string,
    @Query('q') q?: string,
  ) {
    return this.recipes.suggested(user.id, {
      maxMinutes: maxMinutes ? Number(maxMinutes) : undefined,
      cuisine,
      diet,
      q,
    });
  }

  @Get('recipes/search')
  search(
    @CurrentUser() user: User,
    @Query('q') q: string,
    @Query('fromPantry') fromPantry?: string,
  ) {
    return this.recipes.searchRecipes(
      user.id,
      q ?? '',
      fromPantry === 'true' || fromPantry === '1',
    );
  }

  @Get('feed')
  feed(
    @CurrentUser() user: User,
    @Query('cursor') cursor?: string,
    @Query('limit') limit?: string,
  ) {
    return this.recipes.feed(user.id, cursor, limit ? Number(limit) : 20);
  }

  @Get('me/recipes')
  mine(@CurrentUser() user: User) {
    return this.recipes.myRecipes(user.id);
  }

  @Get('me/saved')
  saved(@CurrentUser() user: User) {
    return this.recipes.savedRecipes(user.id);
  }

  @Get('recipes/:id')
  detail(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.findDetail(id, user.id);
  }

  @Post('recipes')
  create(@CurrentUser() user: User, @Body() body: CreateRecipeDto) {
    return this.recipes.create(user.id, body);
  }

  @Post('recipes/:id/photo')
  @UseInterceptors(
    FileInterceptor('file', {
      storage: memoryStorage(),
      limits: { fileSize: 8 * 1024 * 1024 },
    }),
  )
  uploadPhoto(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @UploadedFile() file: Express.Multer.File,
  ) {
    if (!file) throw new BadRequestException('Missing file');
    return this.recipes.uploadPhoto(user.id, id, file);
  }
}
