import { Module } from '@nestjs/common';
import { APP_GUARD } from '@nestjs/core';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { TypeOrmModule, TypeOrmModuleOptions } from '@nestjs/typeorm';
import { join } from 'path';
import { entities } from './entities';
import { AppController } from './app.controller';
import { AuthModule } from './auth/auth.module';
import { AuthGuard } from './auth/auth.guard';
import { UsersModule } from './users/users.module';
import { IngredientsModule } from './ingredients/ingredients.module';
import { PantryModule } from './pantry/pantry.module';
import { RecipesModule } from './recipes/recipes.module';
import { RedisModule } from './redis/redis.module';
import { SearchModule } from './search/search.module';
import { StorageModule } from './storage/storage.module';
import { SeedModule } from './seed/seed.module';
import { ShoppingModule } from './shopping/shopping.module';
import { AdminModule } from './admin/admin.module';
import { PlannerModule } from './planner/planner.module';
import { ReportsModule } from './reports/reports.module';

function typeOrmConfig(config: ConfigService): TypeOrmModuleOptions {
  const dbType = config.get<string>('DB_TYPE') ?? 'postgres';
  const common = {
    entities,
    synchronize: config.get('DB_SYNC') !== 'false',
    autoLoadEntities: true,
  };
  if (dbType === 'sqlite') {
    return {
      ...common,
      type: 'sqljs',
      location: config.get('SQLITE_PATH') || join(process.cwd(), 'dev.sqlite'),
      autoSave: true,
    };
  }
  return {
    ...common,
    type: 'postgres',
    url: config.get<string>('DATABASE_URL'),
  };
}

@Module({
  imports: [
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: [
        join(process.cwd(), '.env'),
        join(process.cwd(), '../.env'),
      ],
    }),
    TypeOrmModule.forRootAsync({
      inject: [ConfigService],
      useFactory: typeOrmConfig,
    }),
    RedisModule,
    SearchModule,
    StorageModule,
    UsersModule,
    AuthModule,
    IngredientsModule,
    PantryModule,
    RecipesModule,
    ShoppingModule,
    SeedModule,
    AdminModule,
    PlannerModule,
    ReportsModule,
  ],
  controllers: [AppController],
  providers: [
    {
      provide: APP_GUARD,
      useClass: AuthGuard,
    },
  ],
})
export class AppModule {}
