import {
  Body,
  Controller,
  Post,
  Req,
  UsePipes,
  ValidationPipe
} from '@nestjs/common'
import { UserToken } from '../auth/get-user.decorator'
import { FirebaseTokenAuthGuard } from '../auth/auth.guard'
import { LoginCodeService } from './login-code.service'
import { CreateLoginCodeDto, CheckLoginCodeDto } from './dto/login-code.dto'

@Controller('login-code')
@UsePipes(
  new ValidationPipe({
    whitelist: true,
    forbidNonWhitelisted: true,
    transform: true
  })
)
export class LoginCodeController {
  constructor(private readonly loginCodeService: LoginCodeService) {}

  @Post('generate-login-code')
  @FirebaseTokenAuthGuard()
  async createLoginCode(
    @UserToken('user_id') userId: string,
    @Body() body: CreateLoginCodeDto
  ) {
    return await this.loginCodeService.createLoginCode(
      userId,
      body.spaceId,
      body.refreshToken
    )
  }

  @Post('check-login-code')
  async checkLoginCode(
    @Body() body: CheckLoginCodeDto,
    @Req() request: { ip?: string }
  ) {
    return await this.loginCodeService.getLoginCodeRecordByLoginCode(
      body.loginCode,
      request.ip
    )
  }
}
