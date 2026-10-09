import { Injectable, Logger } from '@nestjs/common'
import { forwardRef, Inject } from '@nestjs/common'
import { isMongoId } from 'class-validator'
import { SpaceService } from '../space/space.service'
import { Server, WebSocket } from 'ws'
import { FirebaseAuthenticationService } from '../firebase/firebase-authentication.service'
import { RedisPubSubService } from '../redis/redis-pub-sub.service'
import { CHANNELS } from '../redis/redis.channels'
import { v4 as uuidv4 } from 'uuid'

/**
 * @description This is used with WsAuthGuard to ensure that the user is authed before processing a request
 * See: https://github.com/nestjs/nest/issues/882#issuecomment-1493106283
 */
@Injectable()
export class WsAuthHelperService {
  constructor(
    private readonly logger: Logger,
    private readonly redisPubSubService: RedisPubSubService,
    private readonly firebaseAuthService: FirebaseAuthenticationService,
    @Inject(forwardRef(() => SpaceService))
    private readonly spaceService: SpaceService
  ) {}
  public initializationSuccess: { [key: string]: boolean } = {}
  private initializationMap = new Map<string, Promise<any>>()
  /**
   * Primary property for holding subscriptions to channels
   */
  private channelSubs: Record<string, WebSocket[]> = {}

  handleConnectionHelper(client: WebSocket, args: any) {
    client['id'] = uuidv4()
    const clientId = client['id']
    // Defer initialization one microtask so the promise is registered before it
    // can synchronously reject a malformed handshake.
    const initialization = Promise.resolve().then(() =>
      this.initialize(client, args)
    )
    this.initializationMap.set(clientId, initialization)
    void initialization
      .finally(() => {
        this.initializationMap.delete(clientId)
      })
      .catch(() => undefined)
  }

  async finishInitialization(client: WebSocket): Promise<any> {
    return await this.initializationMap.get(client['id'])
  }

  private async initialize(client: WebSocket, args: any): Promise<any> {
    // ensure max listeners is set high enough - nestjs bug (older version causes error)
    client.setMaxListeners(20)

    // WebSocket libraries may supply malformed or missing handshake arguments.
    // Reject them cleanly rather than throwing during connection initialization.
    const handshake =
      Array.isArray(args) &&
      args.length > 0 &&
      args[0] &&
      typeof args[0] === 'object'
        ? args[0]
        : null
    const headers =
      handshake?.headers && typeof handshake.headers === 'object'
        ? handshake.headers
        : null
    if (!headers) {
      this.logger.warn(
        'Rejected WebSocket connection with invalid handshake headers',
        WsAuthHelperService.name
      )
      client.close(1008, 'Invalid handshake')
      return
    }
    let spaceId = headers.space
    let token = headers.authorization

    // Never persist the bearer token on the socket after authentication.

    let isFirebaseToken = false

    // if no token, check for Sec-WebSocket-Protocol header (this is how browsers have to send headers: see #5 here https://stackoverflow.com/a/77060459/3777933)
    if (!token) {
      const secWebSocketProtocol = headers['sec-websocket-protocol']
      if (secWebSocketProtocol) {
        // Important: if this order is changed, it must be changed in ws-auth-helper.service.ts on the react app too. it expects ordered array
        const result = secWebSocketProtocol.split(',')
        token = result[0]
        if (result[1]) {
          spaceId = result[1]
        }
      }
    }

    /*
      check if the token is a valid firebase token
      if it is, set the user object on the client
      this data will be used to check the roles 
      we can catch headers when using WS only during the handleConnection event,
      so here we check the user's token and embed the decrypted token data in the user's connection object 
      when using the Firebase token, methods with role verification will be executed only
     */

    /* 
    if the token is the WSS_SECRET, set the role to admin
        and allows to use methods with admin role
        when using the WSS_SECRET token, methods will be executed only without role verification
      */
    if (token === process.env.WSS_SECRET) {
      client['role'] = 'admin'
    } else {
      try {
        const decodedJwt = await this.decodeJwt(token)
        if (decodedJwt) {
          isFirebaseToken = true
          client['user'] = decodedJwt
        }
      } catch (error) {
        this.logger.log(
          `Invalid tokens (WSS_SECRET or Firebase JWT) for GodotGateway handleConnection: Disconnecting`,
          WsAuthHelperService.name
        )
        return client.close(1014, 'Invalid token')
      }
    }

    // if the token is neither the WSS_SECRET nor a valid firebase token, close the connection
    if (!token || (token !== process.env.WSS_SECRET && !isFirebaseToken)) {
      const msg =
        'Invalid tokens (WSS_SECRET or Firebase JWT) for GodotGateway handleConnection: Disconnecting'
      this.logger.error(msg, WsAuthHelperService.name)
      return client.close(1014, 'Invalid token')
    }

    this.logger.log(
      `handleConnection: ${JSON.stringify(
        {
          spaceId
        },
        null,
        2
      )}`,
      WsAuthHelperService.name
    )
    if (!spaceId || !isMongoId(spaceId)) {
      this.logger.log(
        'Invalid or missing spaceId for authenticated WebSocket connection',
        WsAuthHelperService.name
      )
      return client.close(1008, 'Invalid space')
    }

    if (token !== process.env.WSS_SECRET) {
      try {
        await this.spaceService.findOneWithRolesCheck(
          client['user'].uid,
          spaceId
        )
      } catch (error) {
        this.logger.log(
          'Authenticated user is not authorized for requested space',
          WsAuthHelperService.name
        )
        return client.close(1008, 'Not authorized for space')
      }
    }

    this.setupSubscriber(client, spaceId)

    this.initializationMap.delete(client['id'])
    this.initializationSuccess[client['id']] = true
    return Promise.resolve()
  }

  setupSubscriber(client: WebSocket, spaceId: string) {
    if (!spaceId) {
      this.logger.log(
        `setupSubscriber: attempted but spaceId was falsey: ${JSON.stringify(
          {
            spaceId
          },
          null,
          2
        )}`,
        WsAuthHelperService.name
      )
      return
    }
    const subChannel = `${CHANNELS.SPACE}:${spaceId}`
    client['subscriberChannel'] = subChannel
    // Add to tracked channels
    if (!this.channelSubs[subChannel]) {
      this.channelSubs[subChannel] = new Array<WebSocket>()
    }
    this.channelSubs[subChannel].push(client)
    // setup the subscription listener if this is the first subscriber to the channel.
    if (this.channelSubs[subChannel].length == 1) {
      this.redisPubSubService.subscriber.subscribe(subChannel, (message) => {
        this.handleSubscribedChannelReceivedMessage(subChannel, message)
      })
    }
  }

  /**
   *
   * @description Called when a Redis pubsub message is received from a channel that was subscribed to
   */
  handleSubscribedChannelReceivedMessage(subChannel: string, message: string) {
    const subscribers = this.channelSubs[subChannel]
    if (!subscribers || subscribers.length === 0) {
      return
    }

    // Do not log payloads: they may contain private user or experience data.
    this.logger.debug(
      `Forwarding Redis message on ${subChannel} to ${subscribers.length} subscriber(s)`,
      WsAuthHelperService.name
    )
    this.channelSubs[subChannel] = subscribers.filter((client) => {
      if (client.readyState !== WebSocket.OPEN) {
        return false
      }
      try {
        client.send(message)
        return true
      } catch {
        this.logger.warn(
          'Unable to forward message to a WebSocket subscriber',
          WsAuthHelperService.name
        )
        return false
      }
    })
    if (this.channelSubs[subChannel].length === 0) {
      this.redisPubSubService.subscriber.unsubscribe(subChannel)
      delete this.channelSubs[subChannel]
    }
  }

  removeSubscriber(client: WebSocket) {
    delete this.initializationSuccess[client['id']]
    this.initializationMap.delete(client['id'])

    // remove the client from the channel subscriptions.
    const subchannel = client['subscriberChannel']
    if (!subchannel || !this.channelSubs[subchannel]) {
      this.logger.log(
        `setupSubscriber: attempted but subchannel was falsey: ${JSON.stringify(
          { subchannel }
        )}`,
        WsAuthHelperService.name
      )
      return
    }
    this.channelSubs[subchannel] = this.channelSubs[subchannel].filter(
      (c1) => c1 !== client
    )
    // unsubscribe from the subscription listener if this is the last subscriber to the channel.
    if (this.channelSubs[subchannel].length === 0) {
      this.redisPubSubService.subscriber.unsubscribe(subchannel)
      delete this.channelSubs[subchannel]
    }
  }

  async decodeJwt(token) {
    return await this.firebaseAuthService.verifyIdToken(
      token ? token.replace('Bearer ', '') : '',
      true
    )
  }
}
