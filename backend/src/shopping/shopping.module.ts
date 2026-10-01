import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { ShoppingItem } from '../entities/shopping-item.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { Recipe } from '../entities/recipe.entity';
import { PantryModule } from '../pantry/pantry.module';
import { ShoppingService } from './shopping.service';
import { ShoppingController } from './shopping.controller';

@Module({
  imports: [
    TypeOrmModule.forFeature([ShoppingItem, Ingredient, Recipe]),
    PantryModule,
  ],
  providers: [ShoppingService],
  controllers: [ShoppingController],
  exports: [ShoppingService],
})
export class ShoppingModule {}
