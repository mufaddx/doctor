import { CallHandler, ExecutionContext, Injectable, NestInterceptor } from '@nestjs/common';
import { Observable, tap } from 'rxjs';
import { PrismaService } from '../../database/prisma.service';

/**
 * Persists an audit trail for every state-changing request (POST/PATCH/PUT/DELETE).
 * Read requests are skipped to keep the table lean.
 */
@Injectable()
export class AuditLogInterceptor implements NestInterceptor {
  constructor(private readonly prisma: PrismaService) {}

  intercept(context: ExecutionContext, next: CallHandler): Observable<any> {
    const req = context.switchToHttp().getRequest();
    const mutating = ['POST', 'PATCH', 'PUT', 'DELETE'].includes(req.method);

    return next.handle().pipe(
      tap(async () => {
        if (!mutating) return;
        try {
          await this.prisma.auditLog.create({
            data: {
              userId: req.user?.sub ?? null,
              action: `${req.method} ${req.route?.path ?? req.url}`,
              entityType: context.getClass().name.replace('Controller', ''),
              entityId: req.params?.id ?? null,
              metadata: { body: this.redact(req.body) },
              ipAddress: req.ip,
            },
          });
        } catch {
          // Audit logging must never break the main request flow
        }
      }),
    );
  }

  /** Never store secrets in the audit trail. */
  private redact(body: Record<string, any> = {}) {
    const clone = { ...body };
    for (const key of ['password', 'otp', 'token', 'refreshToken', 'accountNumber']) {
      if (key in clone) clone[key] = '***';
    }
    return clone;
  }
}
