import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Post,
} from '@nestjs/common';
import { IsString, MaxLength, MinLength } from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { OptionalAuth } from '../common/optional-auth.decorator';
import { User } from '../entities/user.entity';
import { RecipesService } from './recipes.service';

class CommentDto {
  @IsString()
  @MinLength(1)
  @MaxLength(500)
  body: string;
}

@Controller('recipes')
export class SocialController {
  constructor(private readonly recipes: RecipesService) {}

  @Post(':id/likes')
  like(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.toggleLike(user.id, id, true);
  }

  @Delete(':id/likes')
  unlike(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.toggleLike(user.id, id, false);
  }

  @Post(':id/saves')
  save(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.toggleSave(user.id, id, true);
  }

  @Post(':id/cooks')
  cook(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.markCooked(user.id, id);
  }

  @Delete(':id/saves')
  unsave(@CurrentUser() user: User, @Param('id') id: string) {
    return this.recipes.toggleSave(user.id, id, false);
  }

  @OptionalAuth()
  @Get(':id/comments')
  comments(@Param('id') id: string) {
    return this.recipes.listComments(id);
  }

  @Post(':id/comments')
  addComment(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() body: CommentDto,
  ) {
    return this.recipes.addComment(user.id, id, body.body);
  }
}
