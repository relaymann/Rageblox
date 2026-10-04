import {
  Injectable,
  CanActivate,
  ExecutionContext,
  ForbiddenException
} from '@nestjs/common'
import { AuthGuardFirebase } from '../../auth/auth.guard'

@Injectable()
export class DomainOrAuthUserGuard implements CanActivate {
  constructor(private readonly authGuardFirebase: AuthGuardFirebase) {}

  async canActivate(context: ExecutionContext): Promise<boolean> {
    const allowedDomains = (process.env.ALLOWED_DOMAINS || '')
      .split(',')
      .map((domain) => domain.trim())
      .filter(Boolean)
    const request = context.switchToHttp().getRequest()
    // get origin from request header
    const origin = request.headers.origin
    let firebaseQuardResult
    try {
      firebaseQuardResult = await this.authGuardFirebase.canActivate(context)
    } catch (error) {
      firebaseQuardResult = false
    }
    // check if domain is allowed or useer is authenticated
    if (
      firebaseQuardResult ||
      (typeof origin === 'string' && allowedDomains.includes(origin))
    ) {
      return true
    }
    throw new ForbiddenException('Forbidden resource')
  }
}
