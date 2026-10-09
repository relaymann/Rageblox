import { describe, expect, it, vi, beforeEach } from 'vitest'
import { WsAuthHelperService } from './ws-auth-helper.service'
import { CHANNELS } from '../redis/redis.channels'

describe('WsAuthHelperService', () => {
  let helper: WsAuthHelperService
  let logger: any
  let redis: any
  let firebaseAuth: any
  let spaceService: any

  beforeEach(() => {
    logger = { log: vi.fn(), warn: vi.fn(), error: vi.fn(), debug: vi.fn() }
    redis = {
      publisher: {},
      subscriber: {
        subscribe: vi.fn(),
        unsubscribe: vi.fn()
      }
    }
    firebaseAuth = {
      verifyIdToken: vi.fn().mockResolvedValue({ uid: 'user-1' })
    }
    spaceService = {
      findOneWithRolesCheck: vi.fn().mockResolvedValue({})
    }
    process.env.WSS_SECRET = 'internal-test-secret'
    helper = new WsAuthHelperService(logger, redis, firebaseAuth, spaceService)
  })

  function socket() {
    return {
      id: 'socket-1',
      setMaxListeners: vi.fn(),
      close: vi.fn(),
      send: vi.fn(),
      readyState: 1
    } as any
  }

  it('rejects a connection with malformed handshake data', async () => {
    const client = socket()

    await (helper as any).initialize(client, [])

    expect(client.close).toHaveBeenCalledWith(1008, 'Invalid handshake')
    expect(redis.subscriber.subscribe).not.toHaveBeenCalled()
  })

  it('rejects a Firebase identity that cannot access the requested space', async () => {
    const client = socket()
    spaceService.findOneWithRolesCheck.mockRejectedValue(new Error('forbidden'))

    await (helper as any).initialize(client, [
      {
        headers: {
          authorization: 'Bearer valid-shaped-token',
          space: '507f1f77bcf86cd799439011'
        }
      }
    ])

    expect(client.close).toHaveBeenCalledWith(1008, 'Not authorized for space')
    expect(redis.subscriber.subscribe).not.toHaveBeenCalled()
  })

  it('does not subscribe a socket that disconnects during space authorization', async () => {
    const client = socket()
    const spaceId = '507f1f77bcf86cd799439011'
    let resolveAuthorization: (value: unknown) => void
    let markAuthorizationStarted: () => void
    const authorizationStarted = new Promise<void>((resolve) => {
      markAuthorizationStarted = resolve
    })
    spaceService.findOneWithRolesCheck.mockImplementation(
      () =>
        new Promise((resolve) => {
          resolveAuthorization = resolve
          markAuthorizationStarted()
        })
    )

    const initialization = (helper as any).initialize(client, [
      {
        headers: {
          authorization: 'Bearer valid-shaped-token',
          space: spaceId
        }
      }
    ])

    await authorizationStarted
    helper.removeSubscriber(client)
    resolveAuthorization!({})
    await initialization

    expect(redis.subscriber.subscribe).not.toHaveBeenCalled()
    expect(helper.initializationSuccess[client.id]).toBeUndefined()
  })

  it('subscribes authorized sockets and releases the Redis subscription on disconnect', async () => {
    const client = socket()
    const spaceId = '507f1f77bcf86cd799439011'

    await (helper as any).initialize(client, [
      {
        headers: {
          authorization: 'Bearer valid-shaped-token',
          space: spaceId
        }
      }
    ])

    expect(spaceService.findOneWithRolesCheck).toHaveBeenCalledWith(
      'user-1',
      spaceId
    )
    expect(redis.subscriber.subscribe).toHaveBeenCalledWith(
      `${CHANNELS.SPACE}:${spaceId}`,
      expect.any(Function)
    )

    helper.removeSubscriber(client)

    expect(redis.subscriber.unsubscribe).toHaveBeenCalledWith(
      `${CHANNELS.SPACE}:${spaceId}`
    )
  })
})
