import { Body, Controller, Get, Put, Post, Query } from '@nestjs/common';
import { IsIn, IsInt, IsOptional, IsString, IsUUID, Matches, Max, Min } from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { PlannerService } from './planner.service';

class SetSlotDto {
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  weekStart: string;

  @IsInt()
  @Min(0)
  @Max(6)
  dayIndex: number;

  @IsIn(['comida', 'cena'])
  meal: string;

  @IsOptional()
  @IsUUID()
  recipeId?: string | null;
}

class WeekDto {
  @IsString()
  @Matches(/^\d{4}-\d{2}-\d{2}$/)
  weekStart: string;
}

@Controller('planner')
export class PlannerController {
  constructor(private readonly planner: PlannerService) {}

  @Get()
  week(@CurrentUser() user: User, @Query('weekStart') weekStart: string) {
    return this.planner.week(user.id, weekStart);
  }

  @Put('slots')
  setSlot(@CurrentUser() user: User, @Body() body: SetSlotDto) {
    return this.planner.setSlot(user.id, body);
  }

  @Post('shopping')
  toShopping(@CurrentUser() user: User, @Body() body: WeekDto) {
    return this.planner.addGapsToShopping(user.id, body.weekStart);
  }
}
