require('dotenv').config()
import { ValidationPipe } from '@nestjs/common'
import helmet from 'helmet'
import { NestFactory } from '@nestjs/core'
import { NestExpressApplication } from '@nestjs/platform-express'
import { WsAdapter } from '@nestjs/platform-ws'
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger'
import { SentryService } from '@ntegral/nestjs-sentry'
import {
  WinstonModule,
  utilities as nestWinstonModuleUtilities
} from 'nest-winston'
import * as os from 'os'
import * as winston from 'winston'
import { AppModule } from './app.module'
import AllExceptionsFilter from './error-handling/all-exceptions.filter'
import metadata from './metadata'
import { NODE_ENV } from './util/node-env.enum'

async function bootstrapRageBloxWebServer() {
  console.log('Starting RageBlox web server')

  const version = require('../package.json').version // eslint-disable-line @typescript-eslint/no-var-requires
  const app = await NestFactory.create<NestExpressApplication>(AppModule, {
    // 2023-07-13 23:04:10: with Winston, there's weirdness with the test setup where the logs get suppressed in tests. This obviously isnt desirable when running tests, so I've added this ternary to not use Winston in tests.
    logger:
      process.env.NODE_ENV === NODE_ENV.TEST
        ? undefined
        : WinstonModule.createLogger({
            transports: [
              new winston.transports.Console({
                format: winston.format.combine(
                  winston.format.timestamp(),
                  winston.format.ms(),
                  nestWinstonModuleUtilities.format.nestLike(
                    'rageblox-server',
                    {
                      colors: true,
                      prettyPrint: true
                    }
                  )
                ),
                level: process.env.NODE_ENV === NODE_ENV.TEST ? 'debug' : 'info'
              })
              // other transports...
            ]
            // other options
          }),
    rawBody: true //**This is required for stripe webhook
  })

  /**
   * Swagger
   */
  await SwaggerModule.loadPluginMetadata(metadata)
  const config = new DocumentBuilder()
    .setTitle('RageBlox Web Server')
    .setDescription('RageBlox platform API')
    .setVersion(version)
    .build()
  const document = SwaggerModule.createDocument(app, config)
  // For the publicly-exposed docs, append random string of characters appended to "hide" it
  SwaggerModule.setup(
    'api-bejmnvpnugdasdfjkasdjfkasjdfjksdfasdui9823hui23',
    app,
    document
  )
  // If on localhost in dev, then still allow for http://localhost:9000/api
  if (
    os.hostname().includes('local') &&
    process.env.NODE_ENV !== 'production' &&
    !process.env.K_REVISION // This is truthy if on GCP cloud run
  ) {
    SwaggerModule.setup('api', app, document)
  }

  const allowedOrigins = (process.env.ALLOWED_DOMAINS || '')
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)

  if (
    process.env.NODE_ENV === NODE_ENV.PRODUCTION &&
    allowedOrigins.length === 0
  ) {
    throw new Error('ALLOWED_DOMAINS must be configured in production')
  }

  app.use(helmet())
  app.enableCors({
    origin: allowedOrigins.length > 0 ? allowedOrigins : '*',
    credentials: allowedOrigins.length > 0
  })
  app.useWebSocketAdapter(new WsAdapter(app))

  // asset storage driver env validation
  if (
    process.env.ASSET_STORAGE_DRIVER === 'GCP' &&
    !process.env.GCS_BUCKET_PUBLIC
  ) {
    throw new Error('GCS_BUCKET_PUBLIC is required when using GCP storage')
  }

  if (
    (!process.env.ASSET_STORAGE_DRIVER ||
      process.env.ASSET_STORAGE_DRIVER === 'LOCAL') &&
    !process.env.ASSET_STORAGE_URL
  ) {
    throw new Error('ASSET_STORAGE_URL is required when using LOCAL storage')
  }

  // Important: This *only* sets up validation pipes for HTTP handlers, NOT Websockets. See the notice here: https://docs.nestjs.com/pipes#global-scoped-pipes
  app.useGlobalPipes(
    new ValidationPipe({
      transform: true,
      whitelist: true,
      enableDebugMessages:
        process.env.NODE_ENV === NODE_ENV.DEVELOPMENT ? true : false
    })
  )

  // Add global exception filter for Sentry to handle 500 errors
  const sentryService = app.get<SentryService>(SentryService)
  app.useGlobalFilters(new AllExceptionsFilter(sentryService))

  const port = process.env.PORT || 9000
  console.log(`Running on port ${port}`)
  await app.listen(port)
}

bootstrapRageBloxWebServer()
