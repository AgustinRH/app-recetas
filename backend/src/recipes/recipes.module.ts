import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Recipe } from '../entities/recipe.entity';
import { RecipeIngredient } from '../entities/recipe-ingredient.entity';
import { RecipeStep } from '../entities/recipe-step.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { Like } from '../entities/like.entity';
import { Comment } from '../entities/comment.entity';
import { SavedRecipe } from '../entities/saved-recipe.entity';
import { RecipesService } from './recipes.service';
import { RecipesController } from './recipes.controller';
import { SocialController } from './social.controller';
import { PantryModule } from '../pantry/pantry.module';

@Module({
  imports: [
    TypeOrmModule.forFeature([
      Recipe,
      RecipeIngredient,
      RecipeStep,
      Ingredient,
      Like,
      Comment,
      SavedRecipe,
    ]),
    PantryModule,
  ],
  providers: [RecipesService],
  controllers: [RecipesController, SocialController],
  exports: [RecipesService],
})
export class RecipesModule {}
