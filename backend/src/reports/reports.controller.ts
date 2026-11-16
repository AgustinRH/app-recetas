import { Body, Controller, Param, Post } from '@nestjs/common';
import { IsIn, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { REPORT_REASONS } from '../entities/recipe-report.entity';
import { ReportsService } from './reports.service';

class ReportDto {
  @IsIn(REPORT_REASONS)
  reason: string;

  @IsOptional()
  @IsString()
  @MaxLength(500)
  note?: string;
}

@Controller('recipes')
export class ReportsController {
  constructor(private readonly reports: ReportsService) {}

  @Post(':id/reports')
  create(
    @CurrentUser() user: User,
    @Param('id') id: string,
    @Body() body: ReportDto,
  ) {
    return this.reports.create(user.id, id, body.reason, body.note ?? '');
  }
}
