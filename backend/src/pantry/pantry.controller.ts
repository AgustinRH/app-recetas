import {
  Body,
  Controller,
  Delete,
  Get,
  Param,
  Patch,
  Post,
} from '@nestjs/common';
import { IsNumber, IsOptional, IsString, IsUUID, Min } from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { PantryService } from './pantry.service';

class CreatePantryDto {
  @IsUUID()
  ingredientId: string;

  @IsOptional()
  @IsNumber()
  @Min(0)
  quantity?: number;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  expiresAt?: string;
}

class PatchPantryDto {
  @IsOptional()
  @IsNumber()
  @Min(0)
  quantity?: number;

  @IsOptional()
  @IsString()
  unit?: string;

  @IsOptional()
  @IsString()
  expiresAt?: string;
}

@Controller('pantry')
export class PantryController {
  constructor(private readonly pantry: PantryService) {}

  @Get()
  list(@CurrentUser() user: User) {
    return this.pantry.list(user.id);
  }

  @Post()
  create(@CurrentUser() user: User, @Body() body: CreatePantryDto) {
    return this.pantry.create(user.id, body);
  }

  @Patch(':id')
  update(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() body: PatchPantryDto,
  ) {
    return this.pantry.update(user.id, id, body);
  }

  @Delete(':id')
  remove(@CurrentUser() user: User, @Param('id') id: string) {
    return this.pantry.remove(user.id, id);
  }
}
