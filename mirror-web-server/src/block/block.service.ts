import {
  ForbiddenException,
  Injectable,
  NotFoundException
} from '@nestjs/common'
import { Types } from 'mongoose'
import { InjectModel } from '@nestjs/mongoose'
import { Model } from 'mongoose'
import { CreateBlockDto } from './dto/create-block.dto'
import { UpdateBlockDto } from './dto/update-block.dto'
import { Block, BlockDocument } from './block.schema'

@Injectable()
export class BlockService {
  constructor(
    @InjectModel(Block.name) private blockModel: Model<BlockDocument>
  ) {}
  createWithOwner(
    userId: string,
    createBlockDto: CreateBlockDto
  ): Promise<BlockDocument> {
    const created = new this.blockModel({
      ...createBlockDto,
      creator: new Types.ObjectId(userId)
    })
    return created.save()
  }

  async findOne(id: string): Promise<BlockDocument> {
    const data = await this.blockModel.findById(id).exec()
    if (data) {
      return data
    } else {
      throw new NotFoundException(`Block not found`)
    }
  }

  async updateWithRolesCheck(
    id: string,
    userId: string,
    updateBlockDto: UpdateBlockDto
  ): Promise<BlockDocument> {
    const block = await this.findOne(id)
    if (block.creator?.toString() !== userId) {
      throw new ForbiddenException('Insufficient block permissions')
    }
    const { _id, creator, mirrorPublicLibrary, ...safeUpdate } =
      updateBlockDto as any
    return this.blockModel
      .findByIdAndUpdate(id, safeUpdate, { new: true })
      .exec()
  }

  async removeWithRolesCheck(
    id: string,
    userId: string
  ): Promise<BlockDocument> {
    const block = await this.findOne(id)
    if (block.creator?.toString() !== userId) {
      throw new ForbiddenException('Insufficient block permissions')
    }
    return this.blockModel
      .findOneAndDelete({ _id: id })
      .exec() as any as Promise<BlockDocument>
  }
}
