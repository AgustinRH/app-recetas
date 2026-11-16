import { Injectable, Logger, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Client as MinioClient } from 'minio';
import { mkdir, writeFile } from 'fs/promises';
import { join } from 'path';
import { randomUUID } from 'crypto';

@Injectable()
export class StorageService implements OnModuleInit {
  private readonly logger = new Logger(StorageService.name);
  private minio: MinioClient | null = null;
  private bucket: string | null = null;

  constructor(private readonly config: ConfigService) {}

  async onModuleInit() {
    const endPoint = this.config.get<string>('MINIO_ENDPOINT');
    if (!endPoint) {
      this.logger.warn('MinIO disabled — using local ./uploads');
      await mkdir(join(process.cwd(), 'uploads', 'recipes'), {
        recursive: true,
      });
      return;
    }
    this.bucket = this.config.get<string>('MINIO_BUCKET') ?? 'dishtoday';
    this.minio = new MinioClient({
      endPoint,
      port: Number(this.config.get('MINIO_PORT') ?? 9000),
      useSSL: this.config.get('MINIO_USE_SSL') === 'true',
      accessKey: this.config.getOrThrow<string>('MINIO_ACCESS_KEY'),
      secretKey: this.config.getOrThrow<string>('MINIO_SECRET_KEY'),
    });
    try {
      const exists = await this.minio.bucketExists(this.bucket);
      if (!exists) await this.minio.makeBucket(this.bucket);
    } catch (err) {
      this.logger.warn(`MinIO unavailable: ${(err as Error).message}`);
      this.minio = null;
      await mkdir(join(process.cwd(), 'uploads', 'recipes'), {
        recursive: true,
      });
    }
  }

  async saveRecipePhoto(recipeId: string, buffer: Buffer, mimeType: string) {
    const ext = mimeType.includes('png')
      ? 'png'
      : mimeType.includes('webp')
        ? 'webp'
        : 'jpg';
    const objectName = `recipes/${recipeId}-${randomUUID()}.${ext}`;
    if (this.minio && this.bucket) {
      await this.minio.putObject(
        this.bucket,
        objectName,
        buffer,
        buffer.length,
        {
          'Content-Type': mimeType,
        },
      );
      const publicBase =
        this.config.get<string>('PUBLIC_BASE_URL') ?? 'http://localhost:9000';
      return `${publicBase}/${this.bucket}/${objectName}`;
    }
    const dest = join(process.cwd(), 'uploads', objectName);
    await mkdir(join(process.cwd(), 'uploads', 'recipes'), { recursive: true });
    await writeFile(dest, buffer);
    const publicBase =
      this.config.get<string>('PUBLIC_BASE_URL') ?? 'http://localhost:3000';
    return `${publicBase}/uploads/${objectName}`;
  }
}
