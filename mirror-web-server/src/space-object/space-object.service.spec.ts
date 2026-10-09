import { RoleModule } from './../roles/role.module'
import { LoggerModule } from './../util/logger/logger.module'
import { SpaceService } from './../space/space.service'
import { RoleService } from './../roles/role.service'
import { Test, TestingModule } from '@nestjs/testing'
import { SpaceObjectModelStub } from '../../test/stubs/spaceObject.model.stub'
import { SpaceObjectService } from './space-object.service'
import { RedisPubSubService } from '../redis/redis-pub-sub.service'
import { PaginationService } from '../util/pagination/pagination.service'
import { AssetService } from '../asset/asset.service'
import { SpaceObjectSearch } from './space-object.search'
import { vi } from 'vitest'

describe('SpaceObjectService', () => {
  let service: SpaceObjectService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      imports: [LoggerModule],
      providers: [
        SpaceObjectService,
        {
          provide: SpaceService,
          useValue: {}
        },
        { provide: RoleService, useValue: {} },
        {
          provide: 'SpaceObjectModel',
          useClass: SpaceObjectModelStub
        },
        { provide: RedisPubSubService, useValue: {} },
        {
          provide: PaginationService,
          useValue: {}
        },
        {
          provide: AssetService,
          useValue: {}
        },
        {
          provide: SpaceObjectSearch,
          useValue: {}
        }
      ]
    }).compile()

    service = module.get<SpaceObjectService>(SpaceObjectService)
  })

  it('does not expose creator email through standard space-object reads', () => {
    const populateFields = (service as any)._standardPopulateFields
    const creatorField = populateFields.find(
      (field) => field.path === 'creator'
    )

    expect(creatorField.select).toEqual(['displayName'])
    expect(creatorField.select).not.toContain('email')
  })

  it('strips client-supplied ownership and role fields before creating objects', async () => {
    vi.spyOn(service as any, 'canCreateWithRolesCheck').mockResolvedValue(true)
    ;(service as any).assetService = {
      isAssetSoftDeleted: vi.fn().mockResolvedValue(false),
      addInstancedAssetToRecents: vi.fn().mockResolvedValue(undefined)
    }
    const createSpy = vi
      .spyOn(service as any, 'createAndNotifyAdmin')
      .mockResolvedValue({})

    await service.createOneWithRolesCheck(
      'user-1' as any,
      {
        spaceId: '507f1f77bcf86cd799439011',
        name: 'safe-name',
        asset: '507f1f77bcf86cd799439012',
        role: { defaultRole: 100 },
        creator: 'attacker',
        space: '507f1f77bcf86cd799439013',
        _id: '507f1f77bcf86cd799439014'
      } as any
    )

    expect(createSpy).toHaveBeenCalledWith({
      creatorUserId: 'user-1',
      spaceId: '507f1f77bcf86cd799439011',
      name: 'safe-name',
      asset: '507f1f77bcf86cd799439012'
    })
  })

  it('strips client-supplied ownership, role, and space fields from updates', async () => {
    vi.spyOn(service as any, '_getSpaceObject').mockResolvedValue({
      space: { _id: '507f1f77bcf86cd799439011' }
    })
    vi.spyOn(service as any, 'canUpdateWithRolesCheck').mockReturnValue(true)
    const updateSpy = vi
      .spyOn(service as any, 'updateOne')
      .mockResolvedValue({})

    await service.updateOneWithRolesCheck(
      'user-1' as any,
      '507f1f77bcf86cd799439012' as any,
      {
        name: 'safe-name',
        space: '507f1f77bcf86cd799439013',
        spaceId: '507f1f77bcf86cd799439013',
        role: { defaultRole: 100 },
        creator: 'attacker',
        _id: '507f1f77bcf86cd799439014'
      } as any
    )

    expect(updateSpy).toHaveBeenCalledWith('507f1f77bcf86cd799439012', {
      name: 'safe-name'
    })
  })

  it('rejects cross-space parent links on updates', async () => {
    vi.spyOn(service as any, '_getSpaceObject').mockResolvedValue({
      space: { _id: '507f1f77bcf86cd799439011' }
    })
    vi.spyOn(service as any, 'canUpdateWithRolesCheck').mockReturnValue(true)
    const query = {
      select: vi.fn().mockReturnThis(),
      exec: vi.fn().mockResolvedValue({
        space: '507f1f77bcf86cd799439013'
      })
    }
    vi.spyOn((service as any).spaceObjectModel, 'findById').mockReturnValue(
      query
    )
    const updateSpy = vi.spyOn(service as any, 'updateOne')

    await expect(
      service.updateOneWithRolesCheck(
        'user-1' as any,
        '507f1f77bcf86cd799439012' as any,
        { parentSpaceObject: '507f1f77bcf86cd799439014' } as any
      )
    ).rejects.toThrow('Parent space object must belong to the same space')

    expect(updateSpy).not.toHaveBeenCalled()
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
