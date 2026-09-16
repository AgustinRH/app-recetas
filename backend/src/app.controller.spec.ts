import { Controller, Get } from '@nestjs/common';
import { Public } from './common/public.decorator';

describe('AppController', () => {
  it('exposes a public health decorator', () => {
    expect(Public).toBeDefined();
    expect(Controller).toBeDefined();
    expect(Get).toBeDefined();
  });
});
