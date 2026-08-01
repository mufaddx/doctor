import { plainToInstance } from 'class-transformer';
import { IsIn, IsNotEmpty, IsNumberString, IsOptional, IsString, validateSync } from 'class-validator';

/**
 * Fails fast at boot if a required environment variable is missing, instead of
 * surfacing confusing runtime errors deep inside a request.
 */
class EnvironmentVariables {
  @IsIn(['development', 'production', 'test'])
  NODE_ENV: string;

  @IsNumberString()
  PORT: string;

  @IsString() @IsNotEmpty()
  DATABASE_URL: string;

  @IsString() @IsNotEmpty()
  REDIS_HOST: string;

  @IsNumberString()
  REDIS_PORT: string;

  @IsString() @IsNotEmpty()
  JWT_ACCESS_SECRET: string;

  @IsString() @IsNotEmpty()
  JWT_REFRESH_SECRET: string;

  @IsString() @IsOptional()
  JWT_ACCESS_EXPIRY?: string;

  @IsString() @IsOptional()
  JWT_REFRESH_EXPIRY?: string;

  @IsString() @IsNotEmpty()
  FIREBASE_PROJECT_ID: string;

  @IsString() @IsNotEmpty()
  FIREBASE_CLIENT_EMAIL: string;

  @IsString() @IsNotEmpty()
  FIREBASE_PRIVATE_KEY: string;

  @IsString() @IsOptional()
  FIREBASE_STORAGE_BUCKET?: string;

  @IsString() @IsNotEmpty()
  RAZORPAY_KEY_ID: string;

  @IsString() @IsNotEmpty()
  RAZORPAY_KEY_SECRET: string;

  @IsString() @IsOptional()
  RAZORPAY_WEBHOOK_SECRET?: string;

  @IsString() @IsNotEmpty()
  AGORA_APP_ID: string;

  @IsString() @IsNotEmpty()
  AGORA_APP_CERTIFICATE: string;

  @IsString() @IsOptional()
  MSG91_AUTH_KEY?: string;

  @IsString() @IsOptional()
  CORS_ORIGINS?: string;
}

export function validateEnv(config: Record<string, unknown>) {
  const parsed = plainToInstance(EnvironmentVariables, config, {
    enableImplicitConversion: true,
  });
  const errors = validateSync(parsed, { skipMissingProperties: false });

  if (errors.length > 0) {
    const details = errors
      .map((e) => `${e.property}: ${Object.values(e.constraints ?? {}).join(', ')}`)
      .join('\n');
    throw new Error(`Invalid environment configuration:\n${details}`);
  }
  return parsed;
}
