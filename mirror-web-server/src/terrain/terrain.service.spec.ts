import { Test, TestingModule } from '@nestjs/testing'
import { TerrainModelStub } from '../../test/stubs/terrain.model.stub'
import { TerrainService } from './terrain.service'
import { FileUploadService } from '../util/file-upload/file-upload.service'

import { SpaceModelStub } from '../../test/stubs/space.model.stub'
import { SpaceService } from '../space/space.service'
import { vi } from 'vitest'

describe('TerrainService', () => {
  let service: TerrainService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TerrainService,
        {
          provide: 'TerrainModel',
          useClass: TerrainModelStub
        },
        {
          provide: 'SpaceModel',
          useClass: SpaceModelStub
        },
        { provide: FileUploadService, useValue: {} },
        { provide: SpaceService, useValue: {} }
      ]
    }).compile()

    service = module.get<TerrainService>(TerrainService)
  })

  it('does not allow role-checked terrain updates to transfer ownership', async () => {
    vi.spyOn(service as any, 'findOne').mockResolvedValue({
      _id: 'terrain-id',
      owner: { toString: () => 'user-1' }
    })
    const updateSpy = vi.spyOn(service as any, 'update').mockResolvedValue({})

    await service.updateWithRolesCheck(
      'terrain-id',
      { name: 'safe-name', owner: 'attacker' } as any,
      'user-1' as any
    )

    expect(updateSpy).toHaveBeenCalledWith('terrain-id', {
      name: 'safe-name'
    })
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
