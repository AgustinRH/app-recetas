import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { User } from '../entities/user.entity';
import { UserPreferences } from '../entities/user-preferences.entity';
import { Recipe } from '../entities/recipe.entity';
import { Like } from '../entities/like.entity';
import { SavedRecipe } from '../entities/saved-recipe.entity';
import { PantryItem } from '../entities/pantry-item.entity';
import { UsersService } from './users.service';
import { UsersController } from './users.controller';

@Module({
  imports: [TypeOrmModule.forFeature([
      User,
      UserPreferences,
      Recipe,
      Like,
      SavedRecipe,
      PantryItem,
    ])],
  providers: [UsersService],
  controllers: [UsersController],
  exports: [UsersService],
})
export class UsersModule {}
