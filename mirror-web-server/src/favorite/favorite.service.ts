import { ForbiddenException, Injectable, NotFoundException } from '@nestjs/common'
import { InjectModel } from '@nestjs/mongoose'
import { Model } from 'mongoose'
import { CreateFavoriteDto } from './dto/create-favorite.dto'
import { UpdateFavoriteDto } from './dto/update-favorite.dto'
import { Favorite, FavoriteDocument } from './favorite.schema'

@Injectable()
export class FavoriteService {
  constructor(
    @InjectModel(Favorite.name) private favoriteModel: Model<FavoriteDocument>
  ) {}
  createForUser(userId: string, dto: CreateFavoriteDto): Promise<FavoriteDocument> {
    const created = new this.favoriteModel({
      ...dto,
      user: userId,
      creator: userId
    })
    return created.save()
  }

  findAllForUser(userId: string): Promise<FavoriteDocument[]> {
    return this.favoriteModel
      .find()
      .where({
        user: userId
      })
      .exec()
  }

  async findOneForUser(id: string, userId: string): Promise<FavoriteDocument> {
    const favorite = await this.favoriteModel.findById(id).exec()
    if (!favorite) throw new NotFoundException()
    if (favorite.user?.toString() !== userId) throw new ForbiddenException()
    return favorite
  }

  async updateForUser(
    id: string,
    userId: string,
    dto: UpdateFavoriteDto
  ): Promise<FavoriteDocument> {
    const favorite = await this.findOneForUser(id, userId)
    const { _id, user, creator, ...safeUpdate } = dto as any
    return this.favoriteModel.findByIdAndUpdate(favorite._id, safeUpdate, { new: true }).exec()
  }

  async removeForUser(id: string, userId: string): Promise<FavoriteDocument> {
    await this.findOneForUser(id, userId)
    return this.favoriteModel.findOneAndDelete({ _id: id }).exec()
  }
}
