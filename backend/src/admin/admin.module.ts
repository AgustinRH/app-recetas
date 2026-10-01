import { Module } from '@nestjs/common';
import { TypeOrmModule } from '@nestjs/typeorm';
import { Comment } from '../entities/comment.entity';
import { Recipe } from '../entities/recipe.entity';
import { RecipeReport } from '../entities/recipe-report.entity';
import { User } from '../entities/user.entity';
import { AdminController } from './admin.controller';
import { AdminService } from './admin.service';

@Module({
  imports: [TypeOrmModule.forFeature([User, Recipe, Comment, RecipeReport])],
  controllers: [AdminController],
  providers: [AdminService],
})
export class AdminModule {}
