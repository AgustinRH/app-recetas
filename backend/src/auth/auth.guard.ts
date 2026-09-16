import {
  CanActivate,
  ExecutionContext,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Reflector } from '@nestjs/core';
import { IS_PUBLIC_KEY } from '../common/public.decorator';
import { UsersService } from '../users/users.service';
import { FirebaseService } from './firebase.service';

@Injectable()
export class AuthGuard implements CanActivate {
  constructor(
    private readonly reflector: Reflector,
    private readonly config: ConfigService,
    private readonly firebase: FirebaseService,
    private readonly users: UsersService,
  ) {}

  async canActivate(context: ExecutionContext) {
    const isPublic = this.reflector.getAllAndOverride<boolean>(IS_PUBLIC_KEY, [
      context.getHandler(),
      context.getClass(),
    ]);
    if (isPublic) return true;

    const request = context.switchToHttp().getRequest();
    const header = request.headers.authorization as string | undefined;
    if (!header?.startsWith('Bearer ')) {
      throw new UnauthorizedException('Missing bearer token');
    }
    const token = header.slice(7).trim();
    const devAuth = this.config.get<string>('DEV_AUTH') === 'true';

    if (devAuth && token.startsWith('dev:')) {
      const identity = token.slice(4);
      const email = identity.includes('@')
        ? identity
        : `${identity}@dishtoday.local`;
      request.user = await this.users.upsertFromAuth({
        firebaseUid: `dev:${email}`,
        email,
        displayName: email.split('@')[0],
      });
      return true;
    }

    if (!this.firebase.isReady()) {
      throw new UnauthorizedException('Firebase Auth is not configured');
    }
    try {
      const decoded = await this.firebase.verifyIdToken(token);
      request.user = await this.users.upsertFromAuth({
        firebaseUid: decoded.uid,
        email: decoded.email ?? null,
        displayName: decoded.name ?? null,
        avatarUrl: decoded.picture ?? null,
      });
      return true;
    } catch {
      throw new UnauthorizedException('Invalid token');
    }
  }
}
