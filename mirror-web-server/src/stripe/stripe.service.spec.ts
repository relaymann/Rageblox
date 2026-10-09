import { beforeEach, describe, expect, it, vi } from 'vitest'
import { StripeService } from './stripe.service'
import { STRIPE_WEBHOOK_TYPES } from './webhooks.types'
import { PREMIUM_ACCESS } from '../option-sets/premium-tiers'

describe('StripeService subscription webhook entitlements', () => {
  const userId = 'user-123'
  let userModel: any
  let stripe: any
  let service: StripeService

  beforeEach(() => {
    process.env.STRIPE_WEBHOOK_SECRET = 'test-webhook-secret'
    userModel = { findByIdAndUpdate: vi.fn().mockResolvedValue({}) }
    stripe = {
      webhooks: {
        constructEvent: vi.fn()
      }
    }
    service = new StripeService(userModel, stripe)
  })

  it('does not grant premium for an incomplete subscription', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_CREATED,
      data: {
        object: {
          id: 'sub-incomplete',
          status: 'incomplete',
          pause_collection: null,
          metadata: { userId }
        }
      }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(userId, {
      stripeSubscriptionId: 'sub-incomplete'
    })
    expect(userModel.findByIdAndUpdate.mock.calls[0][1].$addToSet).toBeUndefined()
  })

  it('grants premium for an active subscription', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_CREATED,
      data: {
        object: {
          id: 'sub-active',
          status: 'active',
          pause_collection: null,
          metadata: { userId }
        }
      }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(userId, {
      stripeSubscriptionId: 'sub-active',
      $addToSet: { premiumAccess: PREMIUM_ACCESS.PREMIUM_1 }
    })
  })

  it('does not revoke access early for a future scheduled cancellation', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_UPDATED,
      data: {
        object: {
          id: 'sub-active',
          status: 'active',
          cancel_at: 1900000000,
          pause_collection: null,
          metadata: { userId }
        }
      }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(userId, {
      $addToSet: { premiumAccess: PREMIUM_ACCESS.PREMIUM_1 }
    })
  })
})
