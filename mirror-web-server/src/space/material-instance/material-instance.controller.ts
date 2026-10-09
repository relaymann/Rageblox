import {
  Controller,
  Get,
  Post,
  Body,
  Patch,
  Param,
  Delete,
  UsePipes,
  ValidationPipe
} from '@nestjs/common'
import { CreateMaterialInstanceDto } from './dto/create-material-instance.dto'
import { UpdateMaterialInstanceDto } from './dto/update-material-instance.dto'
import { MaterialInstanceService } from './material-instance.service'
import { FirebaseTokenAuthGuard } from '../../auth/auth.guard'
import { UserToken } from '../../auth/get-user.decorator'
import { ApiCreatedResponse, ApiParam } from '@nestjs/swagger'
import { ApiResponseProperty } from '@nestjs/swagger/dist/decorators/api-property.decorator'
import { MaterialInstance } from './material-instance.schema'
import {
  MaterialInstanceId,
  SpaceId,
  UserId
} from '../../util/mongo-object-id-helpers'

class MaterialInstanceResponse extends MaterialInstance {
  @ApiResponseProperty()
  _id: string
}

@FirebaseTokenAuthGuard()
@UsePipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true }))
@Controller('space/material-instance')
export class MaterialInstanceController {
  constructor(
    private readonly materialInstanceService: MaterialInstanceService
  ) {}

  @Post()
  @ApiCreatedResponse({
    type: MaterialInstanceResponse
  })
  public async create(
    @Body() createMaterialInstanceDto: CreateMaterialInstanceDto,
    @UserToken('user_id') userId: UserId
  ) {
    return await this.materialInstanceService.create(
      createMaterialInstanceDto,
      userId
    )
  }

  @Get(':spaceId/:materialInstanceId')
  @ApiParam({ name: 'spaceId', type: 'string', required: true })
  @ApiParam({ name: 'materialInstanceId', type: 'string', required: true })
  public async findOne(
    @Param('spaceId') spaceId: SpaceId,
    @Param('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @UserToken('user_id') userId: UserId
  ) {
    return await this.materialInstanceService.findOne(
      spaceId,
      materialInstanceId,
      userId
    )
  }

  @Patch(':spaceId/:materialInstanceId')
  @ApiParam({ name: 'spaceId', type: 'string', required: true })
  @ApiParam({ name: 'materialInstanceId', type: 'string', required: true })
  public async update(
    @Param('spaceId') spaceId: SpaceId,
    @Param('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @Body() updateMaterialInstanceDto: UpdateMaterialInstanceDto,
    @UserToken('user_id') userId: UserId
  ) {
    return await this.materialInstanceService.update(
      spaceId,
      materialInstanceId,
      updateMaterialInstanceDto,
      userId
    )
  }

  @Delete(':spaceId/:materialInstanceId')
  @ApiParam({ name: 'spaceId', type: 'string', required: true })
  @ApiParam({ name: 'materialInstanceId', type: 'string', required: true })
  public async delete(
    @Param('spaceId') spaceId: SpaceId,
    @Param('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @UserToken('user_id') userId: UserId
  ) {
    return await this.materialInstanceService.delete(
      spaceId,
      materialInstanceId,
      userId
    )
  }
}
