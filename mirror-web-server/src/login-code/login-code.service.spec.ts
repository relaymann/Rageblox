import { beforeEach, describe, expect, it, vi } from 'vitest'
import { HttpException, NotFoundException } from '@nestjs/common'
import { LoginCodeService } from './login-code.service'

describe('LoginCodeService', () => {
  let service: LoginCodeService
  let publisher: any
  let loginCodeModel: any
  let findOneAndUpdateQuery: any

  beforeEach(() => {
    const multi = {
      incr: vi.fn(),
      expire: vi.fn(),
      exec: vi.fn().mockResolvedValue([1, 1])
    }
    multi.incr.mockReturnValue(multi)
    multi.expire.mockReturnValue(multi)
    publisher = { multi: vi.fn().mockReturnValue(multi) }
    findOneAndUpdateQuery = {
      exec: vi.fn().mockResolvedValue({
        loginCode: '012345',
        refreshToken: 'refresh-token'
      })
    }
    loginCodeModel = {
      findOneAndUpdate: vi.fn().mockReturnValue(findOneAndUpdateQuery)
    }
    service = new LoginCodeService(
      {} as any,
      {} as any,
      {} as any,
      { publisher } as any,
      loginCodeModel
    )
  })

  it('rejects malformed codes before touching Redis or MongoDB', async () => {
    await expect(
      service.getLoginCodeRecordByLoginCode('12x456', '127.0.0.1')
    ).rejects.toThrow('Login code must be exactly 6 digits')

    expect(publisher.multi).not.toHaveBeenCalled()
    expect(loginCodeModel.findOneAndUpdate).not.toHaveBeenCalled()
  })

  it('enforces the per-IP attempt limit', async () => {
    const multi = publisher.multi()
    multi.exec.mockResolvedValue([31, 1])

    await expect(
      service.getLoginCodeRecordByLoginCode('012345', '127.0.0.1')
    ).rejects.toThrow(HttpException)

    expect(loginCodeModel.findOneAndUpdate).not.toHaveBeenCalled()
  })

  it('atomically consumes only an unused, unexpired login code', async () => {
    const record = await service.getLoginCodeRecordByLoginCode(
      '012345',
      '127.0.0.1'
    )

    expect(record.loginCode).toBe('012345')
    expect(loginCodeModel.findOneAndUpdate).toHaveBeenCalledWith(
      {
        loginCode: '012345',
        usedAt: { $exists: false },
        expiresAt: { $gt: expect.any(Date) }
      },
      { $set: { usedAt: expect.any(Date) } },
      { new: false }
    )
  })

  it('rejects codes that have already been consumed or have expired', async () => {
    findOneAndUpdateQuery.exec.mockResolvedValue(null)

    await expect(
      service.getLoginCodeRecordByLoginCode('012345', '127.0.0.1')
    ).rejects.toThrow(NotFoundException)
  })
})
