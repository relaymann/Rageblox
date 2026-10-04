import { Observable } from 'rxjs'
import {
  Injectable,
  CanActivate,
  ExecutionContext,
  Logger
} from '@nestjs/common'

/**
 * @description Only use for controllers, not websockets
 */
@Injectable()
export class GodotServerGuard implements CanActivate {
  constructor(private readonly logger: Logger) {}

  canActivate(
    context: ExecutionContext
  ): boolean | Promise<boolean> | Observable<boolean> {
    const request = context.switchToHttp().getRequest()
    const secret = process.env.WSS_SECRET
    const authorization = request.headers?.authorization
    const check =
      typeof secret === 'string' &&
      secret.length > 0 &&
      typeof authorization === 'string' &&
      authorization === `Bearer ${secret}`
    if (!check) {
      this.logger.log(
        'Bearer secret Authorization check failed',
        GodotServerGuard.name
      )
    }
    return check
  }
}
