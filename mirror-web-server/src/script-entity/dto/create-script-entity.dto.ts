import { ApiProperty } from '@nestjs/swagger'
import {
  ArrayMaxSize,
  IsArray,
  IsEnum,
  IsNotEmpty,
  IsOptional,
  IsString,
  MaxLength,
  ValidateIf
} from 'class-validator'
import { ROLE } from '../../roles/models/role.enum'

export class CreateScriptEntityDto {
  @ValidateIf((value) => !value.code)
  @IsNotEmpty()
  @IsArray()
  @ArrayMaxSize(4096)
  @ApiProperty()
  blocks: any[] // 2023-07-24 15:18:04 changed from `scripts` to `blocks` to match the Godot client

  @IsOptional()
  @IsString()
  @MaxLength(65536)
  @ApiProperty({ required: false, maxLength: 65536 })
  code?: string

  @IsOptional()
  @IsEnum(ROLE)
  @ApiProperty({
    example: 'The default role permission ',
    enum: ROLE,
    required: false
  })
  defaultRole?: ROLE
}
