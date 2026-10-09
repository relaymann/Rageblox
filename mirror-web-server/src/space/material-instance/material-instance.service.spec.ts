import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ForbiddenException } from '@nestjs/common'
import { MaterialInstanceService } from './material-instance.service'

describe('MaterialInstanceService.delete authorization', () => {
  let service: MaterialInstanceService
  let spaceModel: any
  let spaceService: any

  beforeEach(() => {
    spaceModel = {
      findByIdAndUpdate: vi.fn().mockResolvedValue({ _id: 'space-1' })
    }
    spaceService = {
      getSpace: vi.fn().mockResolvedValue({ _id: 'space-1' }),
      canUpdateWithRolesCheck: vi.fn().mockReturnValue(false)
    }
    service = new MaterialInstanceService(spaceModel, spaceService)
  })

  it('allows the trusted server to delete a material instance', async () => {
    process.env.WSS_SECRET = 'internal-test-secret'

    await expect(
      service.delete(
        '507f1f77bcf86cd799439011' as any,
        '507f1f77bcf86cd799439012' as any,
        process.env.WSS_SECRET
      )
    ).resolves.toBe('507f1f77bcf86cd799439012')

    expect(spaceModel.findByIdAndUpdate).toHaveBeenCalled()
    expect(spaceService.canUpdateWithRolesCheck).not.toHaveBeenCalled()
  })

  it('rejects a regular user without update permission before mutating the space', async () => {
    process.env.WSS_SECRET = 'internal-test-secret'

    await expect(
      service.delete(
        '507f1f77bcf86cd799439011' as any,
        '507f1f77bcf86cd799439012' as any,
        'ordinary-user'
      )
    ).rejects.toThrow(ForbiddenException)

    expect(spaceModel.findByIdAndUpdate).not.toHaveBeenCalled()
  })
})
