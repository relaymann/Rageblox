import { BadRequestException, NotFoundException } from '@nestjs/common'
import { beforeEach, describe, expect, it, vi } from 'vitest'
import { ROLE } from '../roles/models/role.enum'
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
      findById: vi.fn(),
      findByIdAndUpdate: vi.fn(),
      findOneAndUpdate: vi.fn(),
      findOneAndDelete: vi.fn()
    }
    roleService = {
      getRoleCheckAggregationPipeline: vi.fn().mockReturnValue([]),
      checkUserRoleForEntity: vi.fn().mockResolvedValue(true),
      create: vi.fn().mockResolvedValue({ defaultRole: ROLE.CONTRIBUTOR })
    }
    service = new ScriptEntityService(scriptEntityModel, {} as any, roleService)
  })

  it('rejects OWNER as a default role', async () => {
    await expect(
      service.create(creatorId, {
        blocks: [],
        defaultRole: ROLE.OWNER
      })
    ).rejects.toBeInstanceOf(BadRequestException)
  })

  it('rejects invalid role values when called outside HTTP validation', async () => {
    await expect(
      service.create(creatorId, {
        blocks: [],
        defaultRole: 9999 as ROLE
      })
    ).rejects.toBeInstanceOf(BadRequestException)
  })

  it('prevents legacy script creators from injecting role or ownership metadata during updates', async () => {
    const legacyScript = {
      _id: scriptId,
      creator: creatorId,
      blocks: [],
      role: null
    }
    scriptEntityModel.findById.mockReturnValue({
      exec: vi.fn().mockResolvedValue(legacyScript)
    })
    const updateQuery = { exec: vi.fn().mockResolvedValue({}) }
    scriptEntityModel.findByIdAndUpdate.mockReturnValue(updateQuery)

    await service.updateWithRolesCheck(
      scriptId,
      {
        blocks: [],
        role: { defaultRole: ROLE.OWNER, users: { [otherUserId]: ROLE.OWNER } },
        creator: otherUserId,
        _id: otherUserId
      } as any,
      creatorId
    )

    expect(scriptEntityModel.findByIdAndUpdate).toHaveBeenCalledWith(
      scriptId,
      { blocks: [] },
      { new: true }
    )
  })

  it('rejects OWNER as an updated script default role', async () => {
    scriptEntityModel.findById.mockReturnValue({
      exec: vi.fn().mockResolvedValue({
        _id: scriptId,
        creator: creatorId,
        role: { _id: 'role-id' }
      })
    })

    await expect(
      service.updateWithRolesCheck(
        scriptId,
        { defaultRole: ROLE.OWNER },
        creatorId
      )
    ).rejects.toBeInstanceOf(BadRequestException)

    expect(scriptEntityModel.findByIdAndUpdate).not.toHaveBeenCalled()
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
