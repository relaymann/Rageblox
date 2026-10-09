import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common'
import { Types } from 'mongoose'
import { InjectModel } from '@nestjs/mongoose'
import { Model } from 'mongoose'
import { CreateUserGroupDto } from './dto/create-group.users.dto'
import { UpdateUserGroupDto } from './dto/update-group.users.dto'
import { UserGroup, UserGroupDocument } from './user-group.schema'

@Injectable()
export class UserGroupService {
  constructor(
    @InjectModel(UserGroup.name)
    private userGroupModel: Model<UserGroupDocument>
  ) {}

  public create(createUserGroupDto: CreateUserGroupDto): Promise<any> {
    const { owners, moderators, ...safeDto } = createUserGroupDto as any
    const created = new this.userGroupModel({
      ...safeDto,
      owners: [],
      moderators: [],
      users: []
    })
    return created.save()
  }

  public async findOneWithAccess(id: string, userId: string): Promise<any> {
    if (!Types.ObjectId.isValid(id)) throw new NotFoundException('User group not found')
    const group = await this.userGroupModel.findById(id).exec()
    if (!group) throw new NotFoundException('User group not found')
    const isPublic = String(group.public) === 'true'
    if (!isPublic) {
      const isMember =
        group.creator?.toString() === userId ||
        group.owners?.some((owner) => owner.toString() === userId) ||
        group.moderators?.some((moderator) =>
            moderator.toString() === userId) ||
        group.users?.some((user) => user.toString() === userId)
      if (!isMember) throw new ForbiddenException('Insufficient group permissions')
    }
    return [group]
  }

  public findOne(id: string): Promise<any> {
    return this.userGroupModel
      .aggregate<UserGroupDocument[]>()
      .append({ $match: { _id: new Types.ObjectId(id) } })
      .lookup({
        from: 'users',
        localField: 'creator',
        foreignField: '_id',
        as: 'creator'
      })
      .unwind({ path: '$creator' })
      .exec()
  }

  public async updateWithRolesCheck(
    id: string,
    userId: string,
    updateUserGroupDto: UpdateUserGroupDto
  ): Promise<any> {
    const group = await this.userGroupModel.findById(id).exec()
    if (!group) {
      throw new NotFoundException('User group not found')
    }

    const isOwner =
      group.creator?.toString() === userId ||
      group.owners?.some((owner) => owner.toString() === userId)

    if (!isOwner) {
      throw new ForbiddenException('Insufficient group permissions')
    }

    const { _id, creator, owners, users, moderators, ...safeUpdate } =
      updateUserGroupDto as any

    return await this.userGroupModel
      .findByIdAndUpdate(id, safeUpdate, { new: true })
      .exec()
  }

  public async removeWithRolesCheck(id: string, userId: string): Promise<any> {
    const group = await this.userGroupModel.findById(id).exec()
    if (!group) throw new NotFoundException('User group not found')
    if (group.creator?.toString() !== userId) {
      throw new ForbiddenException(
        'Only the group creator can delete the group'
      )
    }
    return this.userGroupModel.findByIdAndDelete(id).exec()
  }

  public update(
    id: string,
    updateUserGroupDto: UpdateUserGroupDto
  ): Promise<any> {
    return this.userGroupModel
      .findByIdAndUpdate(id, updateUserGroupDto, { new: true })
      .exec()
  }

  public remove(id: string): Promise<any> {
    return this.userGroupModel.findOneAndDelete({ _id: id }).exec()
  }

  /**
   * @description Returns all groups where the user is a creator, user, owner, or moderator
   */
  public findAllForUser(userId: string): Promise<any> {
    return this.userGroupModel
      .find()
      .where({
        $or: [
          {
            creator: { $in: [userId] }
          },
          {
            users: { $in: [userId] }
          },
          {
            owners: { $in: [userId] }
          },
          {
            moderators: { $in: [userId] }
          }
        ]
      })
      .exec()
  }

  public search(searchParams): Promise<any> {
    const allowedFields = new Set(['name', 'publicDescription'])
    const filterField = allowedFields.has(searchParams.filterField)
      ? searchParams.filterField
      : 'name'
    const sortField = allowedFields.has(searchParams.sortField)
      ? searchParams.sortField
      : 'name'
    const filterValue =
      typeof searchParams.filterValue === 'string'
        ? searchParams.filterValue.slice(0, 128)
        : ''
    const escapedFilter = filterValue.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
    const sortValue = Number(searchParams.sortValue) === -1 ? -1 : 1
    const limit = Math.min(Math.max(Number(searchParams.limit) || 25, 1), 100)
    const skip = Math.min(Math.max(Number(searchParams.skip) || 0, 0), 100000)

    return this.userGroupModel
      .find({
        public: true,
        [filterField]: { $regex: new RegExp(escapedFilter, 'i') }
      })
      .sort({ [sortField]: sortValue })
      .limit(limit)
      .skip(skip)
      .exec()
  }

  public removeMember(groupId, idUserRemove): Promise<any> {
    return this.userGroupModel
      .findByIdAndUpdate(
        groupId,
        {
          $pull: {
            users: idUserRemove,
            owners: idUserRemove,
            moderators: idUserRemove
          }
        },
        { new: true }
      )
      .exec()
  }

  public async findGroupsInformation(userLinks): Promise<any> {
    const groupsIds = []
    userLinks.map((userLink) => groupsIds.push(userLink.group))

    return await this.userGroupModel.find({ _id: groupsIds })
  }
}
