import { Test, TestingModule } from '@nestjs/testing';
import { INestApplication } from '@nestjs/common';
import * as request from 'supertest';
import { App } from 'supertest/types';
import { AppModule } from './../src/app.module';

process.env.DB_TYPE = 'sqlite';
process.env.SQLITE_PATH = 'health.sqlite';
process.env.DEV_AUTH = 'true';
process.env.SEED_ON_START = 'false';
process.env.REDIS_URL = '';
process.env.TYPESENSE_HOST = '';
process.env.MINIO_ENDPOINT = '';

describe('Health (e2e)', () => {
  let app: INestApplication<App>;

  beforeAll(async () => {
    const moduleFixture: TestingModule = await Test.createTestingModule({
      imports: [AppModule],
    }).compile();

    app = moduleFixture.createNestApplication();
    await app.init();
  });

  afterAll(async () => {
    await app.close();
  });

  it('/health (GET)', () => {
    return request(app.getHttpServer())
      .get('/health')
      .expect(200)
      .expect((res) => {
        expect(res.body.ok).toBe(true);
      });
  });
});
