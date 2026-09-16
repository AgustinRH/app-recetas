import { Injectable } from '@nestjs/common';
import { InjectRepository } from '@nestjs/typeorm';
import { Repository } from 'typeorm';
import { User } from '../entities/user.entity';
import { UserPreferences } from '../entities/user-preferences.entity';

@Injectable()
export class UsersService {
  constructor(
    @InjectRepository(User) private readonly users: Repository<User>,
    @InjectRepository(UserPreferences)
    private readonly prefs: Repository<UserPreferences>,
  ) {}

  async upsertFromAuth(input: {
    firebaseUid: string;
    email?: string | null;
    displayName?: string | null;
    avatarUrl?: string | null;
  }) {
    let user = await this.users.findOne({
      where: { firebaseUid: input.firebaseUid },
      relations: { preferences: true },
    });
    if (!user) {
      user = this.users.create({
        firebaseUid: input.firebaseUid,
        email: input.email ?? null,
        displayName: input.displayName || input.email?.split('@')[0] || 'Chef',
        avatarUrl: input.avatarUrl ?? null,
      });
      user = await this.users.save(user);
      const preferences = this.prefs.create({
        userId: user.id,
        allergies: [],
        diets: [],
      });
      await this.prefs.save(preferences);
      user.preferences = preferences;
      return user;
    }
    if (input.email && !user.email) user.email = input.email;
    if (input.avatarUrl && !user.avatarUrl) user.avatarUrl = input.avatarUrl;
    if (input.displayName && user.displayName === 'Chef') {
      user.displayName = input.displayName;
    }
    return this.users.save(user);
  }

  findById(id: string) {
    return this.users.findOne({ where: { id }, relations: { preferences: true } });
  }

  async updateProfile(
    userId: string,
    data: { displayName?: string; avatarUrl?: string | null },
  ) {
    const user = await this.findById(userId);
    if (!user) return null;
    if (data.displayName !== undefined) user.displayName = data.displayName;
    if (data.avatarUrl !== undefined) user.avatarUrl = data.avatarUrl;
    return this.users.save(user);
  }

  async updatePreferences(
    userId: string,
    data: { allergies?: string[]; diets?: string[] },
  ) {
    let prefs = await this.prefs.findOne({ where: { userId } });
    if (!prefs) {
      prefs = this.prefs.create({
        userId,
        allergies: data.allergies ?? [],
        diets: data.diets ?? [],
      });
    } else {
      if (data.allergies) prefs.allergies = data.allergies;
      if (data.diets) prefs.diets = data.diets;
    }
    return this.prefs.save(prefs);
  }

  toPublic(user: User) {
    return {
      id: user.id,
      email: user.email,
      displayName: user.displayName,
      avatarUrl: user.avatarUrl,
      createdAt: user.createdAt,
      preferences: user.preferences
        ? {
            allergies: user.preferences.allergies ?? [],
            diets: user.preferences.diets ?? [],
          }
        : { allergies: [], diets: [] },
    };
  }
}
