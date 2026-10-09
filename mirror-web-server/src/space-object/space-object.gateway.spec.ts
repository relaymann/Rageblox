import { describe, expect, it, vi, beforeEach } from 'vitest'
import { SpaceObjectGateway } from './space-object.gateway'

describe('SpaceObjectGateway authorization', () => {
  let gateway: SpaceObjectGateway
  let spaceObjectService: any
  let logger: any

  beforeEach(() => {
    spaceObjectService = {
      findOneWithRolesCheck: vi.fn().mockResolvedValue({
        toJSON: () => ({ _id: 'visible-object', space: 'authorized-space' })
      }),
      findOneAdmin: vi.fn(),
      findOneAdminWithPopulatedParentSpaceObject: vi.fn(),
      findOneAdminWithPopulatedParentSpaceObjectRecursiveLookup: vi.fn(),
      findOneAdminWithPopulatedChildSpaceObjectsRecursiveLookup: vi.fn()
    }
    logger = { log: vi.fn() }
    gateway = new SpaceObjectGateway(spaceObjectService, logger)
  })

  it('returns only the role-checked root object for a regular user even when populate flags are requested', async () => {
    const result = await gateway.findOneWithSingleParentSpaceObject(
      false,
      'user-1' as any,
      '507f1f77bcf86cd799439011' as any,
      true,
      true,
      true
    )

    expect(result).toEqual({
      _id: 'visible-object',
      space: 'authorized-space'
    })
    expect(spaceObjectService.findOneWithRolesCheck).toHaveBeenCalledWith(
      'user-1',
      '507f1f77bcf86cd799439011'
    )
    expect(
      spaceObjectService.findOneAdminWithPopulatedParentSpaceObject
    ).not.toHaveBeenCalled()
    expect(
      spaceObjectService.findOneAdminWithPopulatedParentSpaceObjectRecursiveLookup
    ).not.toHaveBeenCalled()
    expect(
      spaceObjectService.findOneAdminWithPopulatedChildSpaceObjectsRecursiveLookup
    ).not.toHaveBeenCalled()
  })

  it('does not read any object for an unauthenticated non-admin connection', async () => {
    const result = await gateway.findOneWithSingleParentSpaceObject(
      false,
      undefined as any,
      '507f1f77bcf86cd799439011' as any
    )

    expect(result).toBeUndefined()
    expect(spaceObjectService.findOneWithRolesCheck).not.toHaveBeenCalled()
    expect(spaceObjectService.findOneAdmin).not.toHaveBeenCalled()
  })

  it('keeps recursive population available to trusted server connections', async () => {
    spaceObjectService.findOneAdminWithPopulatedParentSpaceObjectRecursiveLookup.mockResolvedValue(
      { _id: 'root', parentSpaceObjects: [] }
    )
    spaceObjectService.findOneAdminWithPopulatedChildSpaceObjectsRecursiveLookup.mockResolvedValue(
      { childSpaceObjects: [] }
    )

    const result = await gateway.findOneWithSingleParentSpaceObject(
      true,
      undefined as any,
      '507f1f77bcf86cd799439011' as any,
      false,
      true,
      true
    )

    expect(
      spaceObjectService.findOneAdminWithPopulatedParentSpaceObjectRecursiveLookup
    ).toHaveBeenCalled()
    expect(result.childSpaceObjects).toEqual([])
  })
})
