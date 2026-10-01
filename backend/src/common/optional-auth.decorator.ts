import { SetMetadata } from '@nestjs/common';

/** La ruta responde sin cuenta. Si hay un token válido, se usa. */
export const IS_OPTIONAL_AUTH = 'isOptionalAuth';
export const OptionalAuth = () => SetMetadata(IS_OPTIONAL_AUTH, true);
