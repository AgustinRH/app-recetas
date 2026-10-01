import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Recipe } from '../entities/recipe.entity';
import { RecipeReport } from '../entities/recipe-report.entity';
import { ReportsController } from './reports.controller';
import { ReportsService } from './reports.service';

@Module({
  imports: [TypeOrmModule.forFeature([RecipeReport, Recipe])],
  controllers: [ReportsController],
  providers: [ReportsService],
})
export class ReportsModule {}
