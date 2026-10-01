import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { MealSlot } from '../entities/meal-slot.entity';
import { Recipe } from '../entities/recipe.entity';
import { PantryModule } from '../pantry/pantry.module';
import { ShoppingModule } from '../shopping/shopping.module';
import { PlannerController } from './planner.controller';
import { PlannerService } from './planner.service';

@Module({
  imports: [TypeOrmModule.forFeature([MealSlot, Recipe]), PantryModule, ShoppingModule],
  controllers: [PlannerController],
  providers: [PlannerService],
})
export class PlannerModule {}
