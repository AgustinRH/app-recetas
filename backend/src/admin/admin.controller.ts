import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Query,
  UseGuards,
} from '@nestjs/common';
import { IsBoolean } from 'class-validator';
import { AdminGuard } from '../auth/admin.guard';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { AdminService } from './admin.service';

class BanDto {
  @IsBoolean()
  banned: boolean;
}

@Controller('admin')
@UseGuards(AdminGuard)
export class AdminController {
  constructor(private readonly admin: AdminService) {}

  @Get('summary')
  summary() {
    return this.admin.summary();
  }

  @Get('users')
  users(@Query('q') q?: string) {
    return this.admin.listUsers(q?.trim() || undefined);
  }

  @Patch('users/:id')
  setBanned(
    @CurrentUser() actor: User,
    @Param('id') id: string,
    @Body() body: BanDto,
  ) {
    return this.admin.setBanned(actor.id, id, body.banned);
  }

  @Get('recipes')
  recipes(@Query('q') q?: string) {
    return this.admin.listRecipes(q?.trim() || undefined);
  }

  @Delete('recipes/:id')
  deleteRecipe(@Param('id') id: string) {
    return this.admin.deleteRecipe(id);
  }

  @Get('comments')
  comments(@Query('q') q?: string) {
    return this.admin.listComments(q?.trim() || undefined);
  }

  @Delete('comments/:id')
  deleteComment(@Param('id') id: string) {
    return this.admin.deleteComment(id);
  }

  @Get('reports')
  reports(@Query('q') q?: string) {
    return this.admin.listReports(q?.trim() || undefined);
  }

  @Patch('reports/:id')
  dismissReport(@Param('id') id: string) {
    return this.admin.dismissReport(id);
  }
}
