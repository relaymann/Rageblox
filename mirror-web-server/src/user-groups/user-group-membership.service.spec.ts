import { vi, expect, describe, it } from 'vitest'
import { UserGroupMembershipService } from './user-group-membership.service'

describe('UserGroupMembershipService', () => {
  it('excludes memberships whose group is private or missing after population', async () => {
    const memberships = [
      { user: { _id: 'public-user' }, group: { public: true } },
      { user: { _id: 'private-user' }, group: null },
      { user: { _id: 'legacy-public-user' }, group: { public: 'true' } }
    ]
    const query = {
      populate: vi.fn(),
      exec: vi.fn().mockResolvedValue(memberships)
    }
    query.populate.mockReturnValue(query)

    const model = {
      find: vi.fn().mockReturnValue(query)
    }
    const service = new UserGroupMembershipService(model as any)

    const result = await service.getAllPublicMembersForPublicGroup('group-id')

    expect(model.find).toHaveBeenCalledWith({
      group: 'group-id',
      membershipIsPubliclyVisible: true
    })
    expect(query.populate).toHaveBeenNthCalledWith(1, {
      path: 'group',
      match: { public: { $in: [true, 'true'] } },
      select: ['public']
    })
    expect(result).toEqual([memberships[0], memberships[2]])
  })
})
