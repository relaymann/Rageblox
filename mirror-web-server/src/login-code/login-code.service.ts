import {
  BadRequestException,
  Injectable,
  NotFoundException,
  HttpException,
  HttpStatus
} from '@nestjs/common'
import { UserService } from '../user/user.service'
import { UserId } from '../util/mongo-object-id-helpers'
import { ObjectId } from 'mongodb'
import { randomInt } from 'crypto'
import { LoginCode, LoginCodeDocument } from './login-code.schema'
import { InjectModel } from '@nestjs/mongoose'
import { User, UserDocument } from '../user/user.schema'
import { Model } from 'mongoose'
import { SpaceService } from '../space/space.service'
import { RedisPubSubService } from '../redis/redis-pub-sub.service'
@Injectable()
export class LoginCodeService {
  constructor(
    private readonly userService: UserService,
    @InjectModel(User.name)
    private userModel: Model<UserDocument>,
    private readonly spaceService: SpaceService,
    private readonly redisPubSubService: RedisPubSubService,
    @InjectModel(LoginCode.name)
    private loginCodeModel: Model<LoginCodeDocument>
  ) {}

  // generate 6 digit login code
  private _generateLoginCode(length = 6): string {
    const max = 10 ** length
    return randomInt(0, max).toString().padStart(length, '0')
  }

  public async createLoginCode(
    userId: UserId,
    spaceId: string,
    refreshToken: string
  ): Promise<LoginCode> {
    let uniqueLoginCode = this._generateLoginCode()

    const user = await this.userService.findOneAdmin(userId)

    if (!user) {
      throw new BadRequestException('User not found')
    }

    const space = await this.spaceService.getSpace(spaceId)

    if (!space || !this.spaceService.canFindWithRolesCheck(userId, space)) {
      throw new BadRequestException('Space not found')
    }

    // check if login code is unique
    while (await this.loginCodeModel.findOne({ loginCode: uniqueLoginCode })) {
      uniqueLoginCode = this._generateLoginCode()
    }

    const createdLoginCode = new this.loginCodeModel({
      userId: new ObjectId(userId),
      refreshToken: refreshToken,
      spaceId: new ObjectId(spaceId),
      loginCode: uniqueLoginCode,
      expiresAt: new Date(Date.now() + 5 * 60 * 1000)
    })
    return await createdLoginCode.save()
  }

  public async getLoginCodeRecordByLoginCode(
    loginCode: string,
    requesterIp?: string
  ): Promise<LoginCode> {
    if (!requesterIp || requesterIp.length > 128) {
      throw new BadRequestException('Invalid requester')
    }

    const rateLimitKey = `login-code:check:${requesterIp}`
    const rateLimitResult = await this.redisPubSubService.publisher
      .multi()
      .incr(rateLimitKey)
      .expire(rateLimitKey, 60)
      .exec()
    const attempts = Number(rateLimitResult?.[0])
    if (attempts > 30) {
      throw new HttpException('Too many login-code attempts', HttpStatus.TOO_MANY_REQUESTS)
    }
    const loginCodeRecord = await this.loginCodeModel
      .findOneAndUpdate(
        {
          loginCode,
          usedAt: { $exists: false },
          expiresAt: { $gt: new Date() }
        },
        { $set: { usedAt: new Date() } },
        { new: false }
      )
      .exec()
    if (!loginCodeRecord) {
      throw new NotFoundException('Login code is invalid, expired, or already used')
    }
    return loginCodeRecord
  }
}
