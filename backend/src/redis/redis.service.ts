import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(RedisService.name);
  private client: Redis | null = null;

  constructor(private readonly config: ConfigService) {}

  onModuleInit() {
    const url = this.config.get<string>('REDIS_URL');
    if (!url) {
      this.logger.warn('Redis disabled (no REDIS_URL)');
      return;
    }
    this.client = new Redis(url, {
      maxRetriesPerRequest: 1,
      retryStrategy: () => null,
      lazyConnect: true,
    });
    this.client.connect().catch((err) => {
      this.logger.warn(`Redis unavailable: ${err.message}`);
      this.client = null;
    });
  }

  async onModuleDestroy() {
    if (this.client) await this.client.quit();
  }

  async get(key: string): Promise<string | null> {
    if (!this.client) return null;
    try {
      return await this.client.get(key);
    } catch {
      return null;
    }
  }

  async setex(key: string, ttlSeconds: number, value: string) {
    if (!this.client) return;
    try {
      await this.client.setex(key, ttlSeconds, value);
    } catch {
      /* ignore */
    }
  }

  async del(key: string) {
    if (!this.client) return;
    try {
      await this.client.del(key);
    } catch {
      /* ignore */
    }
  }
}
