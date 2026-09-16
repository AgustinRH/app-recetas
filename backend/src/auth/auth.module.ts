import { Module } from '@nestjs/common';
import { FirebaseService } from './firebase.service';
import { AuthGuard } from './auth.guard';
import { UsersModule } from '../users/users.module';

@Module({
  imports: [UsersModule],
  providers: [FirebaseService, AuthGuard],
  exports: [FirebaseService, AuthGuard],
})
export class AuthModule {}
