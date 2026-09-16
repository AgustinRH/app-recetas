import { Body, Controller, Get, Patch, Post } from '@nestjs/common';
import { IsArray, IsOptional, IsString, MaxLength } from 'class-validator';
import { CurrentUser } from '../common/current-user.decorator';
import { User } from '../entities/user.entity';
import { UsersService } from '../users/users.service';

class SyncAuthDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;
}

class PatchMeDto {
  @IsOptional()
  @IsString()
  @MaxLength(80)
  displayName?: string;

  @IsOptional()
  @IsString()
  avatarUrl?: string;
}

class PatchPreferencesDto {
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  allergies?: string[];

  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  diets?: string[];
}

@Controller()
export class UsersController {
  constructor(private readonly users: UsersService) {}

  @Post('auth/sync')
  async sync(@CurrentUser() user: User, @Body() body: SyncAuthDto) {
    if (body.displayName) {
      await this.users.updateProfile(user.id, { displayName: body.displayName });
    }
    const fresh = await this.users.findById(user.id);
    return this.users.toPublic(fresh!);
  }

  @Get('me')
  async me(@CurrentUser() user: User) {
    const fresh = await this.users.findById(user.id);
    return this.users.toPublic(fresh!);
  }

  @Patch('me')
  async patchMe(@CurrentUser() user: User, @Body() body: PatchMeDto) {
    const updated = await this.users.updateProfile(user.id, body);
    return this.users.toPublic(updated!);
  }

  @Patch('me/preferences')
  async patchPreferences(
    @CurrentUser() user: User,
    @Body() body: PatchPreferencesDto,
  ) {
    const preferences = await this.users.updatePreferences(user.id, body);
    const fresh = await this.users.findById(user.id);
    return {
      ...this.users.toPublic(fresh!),
      preferences: {
        allergies: preferences.allergies,
        diets: preferences.diets,
      },
    };
  }
}
