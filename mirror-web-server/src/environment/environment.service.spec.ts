import { Test, TestingModule } from '@nestjs/testing'
import { EnvironmentService } from './environment.service'
import { EnvironmentModelStub } from '../../test/stubs/environment.model.stub'
import { SpaceService } from '../space/space.service'
import { vi } from 'vitest'

describe('EnvironmentService', () => {
  let service: EnvironmentService

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        EnvironmentService,
        { provide: 'EnvironmentModel', useClass: EnvironmentModelStub },
        {
          provide: 'SpaceModel',
          useValue: {}
        },
        {
          provide: SpaceService,
          useValue: {}
        }
      ]
    }).compile()

    service = module.get<EnvironmentService>(EnvironmentService)
  })

  it('does not let environment updates replace identity or timestamps', async () => {
    const id = '507f1f77bcf86cd799439011'
    const environmentQuery = {
      exec: vi.fn().mockResolvedValue({ _id: id })
    }
    const spaceQuery = {
      exec: vi.fn().mockResolvedValue({ _id: id })
    }
    const updateQuery = {
      exec: vi.fn().mockResolvedValue({})
    }
    vi.spyOn((service as any).environmentModel, 'findById').mockReturnValue(
      environmentQuery
    )
    vi.spyOn(
      (service as any).environmentModel,
      'findByIdAndUpdate'
    ).mockReturnValue(updateQuery)
    ;(service as any).spaceModel = {
      findOne: vi.fn().mockReturnValue(spaceQuery)
    }
    ;(service as any).spaceService = {
      getSpace: vi.fn().mockResolvedValue({}),
      canUpdateWithRolesCheck: vi.fn().mockReturnValue(true)
    }

    await service.updateWithRolesCheck(
      id,
      {
        skyTopColor: [0.1, 0.2, 0.3],
        _id: '507f1f77bcf86cd799439012',
        createdAt: new Date(0),
        updatedAt: new Date(0)
      } as any,
      'user-1' as any
    )

    expect((service as any).environmentModel.findByIdAndUpdate).toHaveBeenCalledWith(
      id, { skyTopColor: [0.1, 0.2, 0.3] }, { new: true }
    )
  })

  it('should be defined', () => {
    expect(service).toBeDefined()
  })
})
