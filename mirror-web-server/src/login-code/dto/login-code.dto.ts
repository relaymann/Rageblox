import {
  IsMongoId,
  IsNotEmpty,
  IsString,
  Matches,
  MaxLength
} from 'class-validator'

export class CreateLoginCodeDto {
  @IsMongoId()
  spaceId: string

  @IsString()
  @IsNotEmpty()
  @MaxLength(4096)
  refreshToken: string
}

export class CheckLoginCodeDto {
  @IsString()
  @Matches(/^\d{6}$/)
  loginCode: string
}
