import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { PantryItem } from '../entities/pantry-item.entity';
import { Ingredient } from '../entities/ingredient.entity';
import { PantryService } from './pantry.service';
import { PantryController } from './pantry.controller';

@Module({
  imports: [TypeOrmModule.forFeature([PantryItem, Ingredient])],
  providers: [PantryService],
  controllers: [PantryController],
  exports: [PantryService],
})
export class PantryModule {}
