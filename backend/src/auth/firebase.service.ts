import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  applicationDefault,
  cert,
  getApps,
  initializeApp,
} from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';

@Injectable()
export class FirebaseService implements OnModuleInit {
  private readonly logger = new Logger(FirebaseService.name);
  private ready = false;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const projectId = this.config.get<string>('FIREBASE_PROJECT_ID');
    if (!projectId) {
      this.logger.warn('Firebase Auth disabled (no FIREBASE_PROJECT_ID)');
      return;
    }
    const raw = this.config.get<string>('FIREBASE_SERVICE_ACCOUNT');
    const credential = raw ? cert(JSON.parse(raw)) : applicationDefault();
    if (!getApps().length) {
      initializeApp({ credential, projectId });
    }
    this.ready = true;
    this.logger.log(`Firebase Admin initialized for ${projectId}`);
  }

  isReady() {
    return this.ready;
  }

  verifyIdToken(token: string) {
    return getAuth().verifyIdToken(token, true);
  }
}
