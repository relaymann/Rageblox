import { NotFoundException } from '@nestjs/common'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ScriptEntityService } from './script-entity.service'

const scriptId = '64b000000000000000000001'
const creatorId = '64b000000000000000000002'
const otherUserId = '64b000000000000000000003'

describe('ScriptEntityService legacy script authorization', () => {
  let service: ScriptEntityService
  let scriptEntityModel: any
  let roleService: any

  beforeEach(() => {
    scriptEntityModel = {
      aggregate: vi.fn().mockResolvedValue([]),
      findOne: vi.fn(),
      findOneAndUpdate: vi.fn(),
      findOneAndDelete: vi.fn()
    }
    roleService = {
      getRoleCheckAggregationPipeline: vi.fn().mockReturnValue([])
    }
    service = new ScriptEntityService(
      scriptEntityModel,
      {} as any,
      roleService
    )
  })

  it('allows the creator to read a legacy script with no role metadata', async () => {
    const legacyScript = {
      _id: scriptId,
      creator: creatorId,
      blocks: [],
      role: null
    }
    const exec = vi.fn().mockResolvedValue(legacyScript)
    scriptEntityModel.findOne.mockReturnValue({ exec })

    await expect(
      service.findOneWithRolesCheck(scriptId, creatorId)
    ).resolves.toBe(legacyScript)

    expect(scriptEntityModel.findOne).toHaveBeenCalledWith({
      _id: scriptId,
      role: null,
      creator: creatorId
    })
  })

  it('does not let another user read a legacy script', async () => {
    const exec = vi.fn().mockResolvedValue(null)
    scriptEntityModel.findOne.mockReturnValue({ exec })

    await expect(
      service.findOneWithRolesCheck(scriptId, otherUserId)
    ).rejects.toBeInstanceOf(NotFoundException)

    expect(scriptEntityModel.findOne).toHaveBeenCalledWith({
      _id: scriptId,
      role: null,
      creator: otherUserId
    })
  })
})
