import { beforeEach, describe, expect, it, vi } from 'vitest'
import { StripeService } from './stripe.service'
import { STRIPE_WEBHOOK_TYPES } from './webhooks.types'
import { PREMIUM_ACCESS } from '../option-sets/premium-tiers'

describe('StripeService subscription webhook entitlements', () => {
  const userId = 'user-123'
  let userModel: any
  let stripe: any
  let service: StripeService

  const subscription = (overrides: Record<string, any> = {}) => ({
    id: 'sub-active',
    status: 'active',
    pause_collection: null,
    metadata: { userId },
    items: { data: [{ price: { id: 'price-premium' } }] },
    ...overrides
  })

  beforeEach(() => {
    process.env.STRIPE_WEBHOOK_SECRET = 'test-webhook-secret'
    process.env.STRIPE_PREMIUM_PRICE_ID = 'price-premium'
    userModel = {
      findByIdAndUpdate: vi.fn().mockResolvedValue({}),
      findOneAndUpdate: vi.fn().mockResolvedValue({})
    }
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
      data: { object: subscription({ status: 'incomplete' }) }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findByIdAndUpdate).toHaveBeenCalledWith(userId, {
      stripeSubscriptionId: 'sub-active'
    })
  })

  it('grants premium only for the configured active price', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_CREATED,
      data: { object: subscription() }
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
      data: { object: subscription({ cancel_at: 1900000000 }) }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: userId, stripeSubscriptionId: 'sub-active' },
      { $addToSet: { premiumAccess: PREMIUM_ACCESS.PREMIUM_1 } }
    )
  })

  it('does not grant premium for a non-premium price', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_CREATED,
      data: {
        object: subscription({
          items: { data: [{ price: { id: 'price-unrelated' } }] }
        })
      }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findByIdAndUpdate).not.toHaveBeenCalled()
    expect(userModel.findOneAndUpdate).not.toHaveBeenCalled()
  })

  it('does not let an old subscription deletion revoke a newer subscription', async () => {
    stripe.webhooks.constructEvent.mockReturnValue({
      type: STRIPE_WEBHOOK_TYPES.SUBSCRIPTION_DELETED,
      data: { object: subscription({ id: 'sub-old', status: 'canceled' }) }
    })

    await service.handleStripeWebhook('body', 'signature')

    expect(userModel.findOneAndUpdate).toHaveBeenCalledWith(
      { _id: userId, stripeSubscriptionId: 'sub-old' },
      {
        $pull: { premiumAccess: PREMIUM_ACCESS.PREMIUM_1 },
        $unset: { stripeSubscriptionId: 1 }
      }
    )
  })
})
