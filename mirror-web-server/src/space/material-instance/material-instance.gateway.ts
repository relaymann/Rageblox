import { Logger, UseFilters, UseGuards, UseInterceptors } from '@nestjs/common'
import {
  ConnectedSocket,
  MessageBody,
  SubscribeMessage,
  WebSocketGateway
} from '@nestjs/websockets'
import { WebSocket } from 'ws'
import { GodotSocketExceptionFilter } from '../../godot-server/godot-socket-exception.filter'
import { GodotSocketInterceptor } from '../../godot-server/godot-socket.interceptor'
import { CreateMaterialInstanceDto } from './dto/create-material-instance.dto'
import { UpdateMaterialInstanceDto } from './dto/update-material-instance.dto'
import { MaterialInstanceService } from './material-instance.service'
import { MaterialInstanceId, SpaceId } from '../../util/mongo-object-id-helpers'
import { WsAuthGuard } from '../../godot-server/ws-auth.guard'

enum ZoneMaterialInstanceMessage {
  CREATE_ONE = 'zone_create_material_instance',
  GET_ONE = 'zone_get_material_instance',
  UPDATE_ONE = 'zone_update_material_instance',
  DELETE_ONE = 'zone_delete_material_instance'
}

@WebSocketGateway()
@UseGuards(WsAuthGuard)
@UseInterceptors(GodotSocketInterceptor)
@UseFilters(GodotSocketExceptionFilter)
export class MaterialInstanceGateway {
  constructor(
    private readonly materialInstanceService: MaterialInstanceService,
    private readonly logger: Logger
  ) {}

  @SubscribeMessage(ZoneMaterialInstanceMessage.CREATE_ONE)
  public createMaterialInstance(
    @MessageBody('dto') createMaterialInstanceDto: CreateMaterialInstanceDto,
    @ConnectedSocket() client: WebSocket
  ) {
    this.logger.log(
      `${JSON.stringify(
        {
          ZoneSpaceObjectWsMessage: ZoneMaterialInstanceMessage.CREATE_ONE,
          createMaterialInstanceDto
        },
        null,
        2
      )}`,
      MaterialInstanceGateway.name
    )
    return this.materialInstanceService.create(
      createMaterialInstanceDto,
      this.getAuthenticatedUserId(client)
    )
  }

  @SubscribeMessage(ZoneMaterialInstanceMessage.GET_ONE)
  public findOneMaterialInstance(
    @MessageBody('spaceId') spaceId: SpaceId,
    @MessageBody('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @ConnectedSocket() client: WebSocket
  ) {
    this.logger.log(
      `${JSON.stringify(
        {
          ZoneSpaceObjectWsMessage: ZoneMaterialInstanceMessage.GET_ONE,
          spaceId,
          materialInstanceId
        },
        null,
        2
      )}`,
      MaterialInstanceGateway.name
    )
    return this.materialInstanceService.findOne(
      spaceId,
      materialInstanceId,
      this.getAuthenticatedUserId(client)
    )
  }

  @SubscribeMessage(ZoneMaterialInstanceMessage.UPDATE_ONE)
  public updateOne(
    @MessageBody('spaceId') spaceId: SpaceId,
    @MessageBody('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @MessageBody('dto') updateMaterialInstanceDto: UpdateMaterialInstanceDto,
    @ConnectedSocket() client: WebSocket
  ) {
    // 2023-07-24 15:07:57 I'm changing this log format to not use JSON.stringify and deploying that to dev. The rest should follow suit if that fixes the logs
    this.logger.log(
      {
        ZoneSpaceObjectWsMessage: ZoneMaterialInstanceMessage.UPDATE_ONE,
        spaceId,
        materialInstanceId,
        'dto (updateMaterialInstanceDto)': updateMaterialInstanceDto
      },
      MaterialInstanceGateway.name
    )
    return this.materialInstanceService.update(
      spaceId,
      materialInstanceId,
      updateMaterialInstanceDto,
      this.getAuthenticatedUserId(client)
    )
  }

  @SubscribeMessage(ZoneMaterialInstanceMessage.DELETE_ONE)
  public deleteOne(
    @MessageBody('spaceId') spaceId: SpaceId,
    @MessageBody('materialInstanceId') materialInstanceId: MaterialInstanceId,
    @ConnectedSocket() client: WebSocket
  ) {
    this.logger.log(
      `${JSON.stringify(
        {
          ZoneSpaceObjectWsMessage: ZoneMaterialInstanceMessage.DELETE_ONE,
          spaceId,
          materialInstanceId
        },
        null,
        2
      )}`,
      MaterialInstanceGateway.name
    )
    return this.materialInstanceService.delete(
      spaceId,
      materialInstanceId,
      this.getAuthenticatedUserId(client)
    )
  }

  private getAuthenticatedUserId(client: WebSocket): string {
    if (client['role'] === 'admin' && process.env.WSS_SECRET) {
      return process.env.WSS_SECRET
    }
    const userId = client['user']?.uid
    if (typeof userId !== 'string' || !userId) {
      throw new Error('Authenticated WebSocket user is missing')
    }
    return userId
  }
}
