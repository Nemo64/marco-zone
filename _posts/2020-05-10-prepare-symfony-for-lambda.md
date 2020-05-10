---
title:       Configure symfony for lambda
description: Here are some configurations you need to set or be aware of when using symfony in AWS lambda using bref. 
categories:
    - AWS
    - serverless
    - Software-Development
date:        2020-05-10 20:00:00 +0200
lastmod:     2020-05-10 20:00:00 +0200
---

I'm going to assume a few things:

- You have already played around with [bref].
  If not, go to the excellent [bref documentation] and start with a simple php example.
  There is also a part on hosting symfony. I'm going to build on that.
- You use the full symfony/skeleton. The minimal version is similar but not everything here is needed.
- You use Symfony 4.4 or 5.0. Future version may differ.
- You are using `serverless`. This is the obvious choice if you followed the [bref documentation].
- You are hosting or at least testing in `us-east-1`, `us-east-2`, `us-west-2` or `eu-west-1`.
  Other regions will have limitations in this guide since not all services are available everywhere.
  I'll mention if a service is strangely limited but if you stick to the regions above, you won't have any problems.

## Table of contents

This is bigger than my usual posts so I'm going to include the headlines here:

- [What do I want](#what-do-i-want)
- [Creating the "lambda" environment](#creating-the-lambda-environment)
- [Configure caching](#configure-caching)
- [Configure logging](#configure-logging)
- [Configure assets (and distribution)](#configure-assets-and-distribution)
- [Configure sessions (and the aws-sdk)](#configure-sessions-and-the-aws-sdk)
- [Configure mailing](#configure-mailing)
- [Configure doctrine](#configure-doctrine)

## What do I want

- I want a symfony installation that can run using bref in aws lambda.
- I want to develop and test my application locally and even be able to host the application in a classic environment if necessary.
- I want my changes to be obvious. I don't want to modify to many files in the symfony skeleton
  as it would make it difficult to understand for anyone going into the project.
  (this is also why I write this documentation)
  
### Disclaimer

I'm writing this guide from memory and by copy&pasting from a working project so I have probably forgotten some things.
If I notice that I missed something I'll add it later.
I'll also try to update it when things get easier.

## Creating the "lambda" environment

The Symfony skeleton comes with 3 environments. `dev`, `test` and `prod`.
However, while those are the defaults, nobody is forcing you to stick with those.

Because running in lambda is very different from running locally, I like to configure a "lambda" environment.

You can read the symfony documentation on how to [create an environment]
but you basically create a folder in `config/packages/[environment name]`
or in our case `config/packages/lambda` and you'll be able to use `app/console --env=lambda`.

```diff
 your-project/
 ├─ config/
 ├─ ├─ packages/
 ├─ ├─ ├─ dev/
+├─ ├─ ├─ lambda/ # your new environment
 └─ └─ └─ prod/
```

To start: you can copy all files from `prod/` to `lambda/` but we'll modify them.

Doing this has some advantages:

- I don't need to touch the normal `prod` configuration and can therefore still use it outside lambda
- My lambda modifications are obvious and mostly limited to this folder

Now I'm going to shoot my last argument a bit since there is 1 modification needed outside the `lambda/` folder.
Every environment will be `debug=true` by default which isn't that big of a deal if you set the `APP_DEBUG` environment variable to `0`
but I want debug to default to false there, so I need to modify `config/bootstrap.php`.

```diff
- $_SERVER['APP_DEBUG'] = $_SERVER['APP_DEBUG'] ?? $_ENV['APP_DEBUG'] ?? 'prod' !== $_SERVER['APP_ENV'];
+ $_SERVER['APP_DEBUG'] = $_SERVER['APP_DEBUG'] ?? $_ENV['APP_DEBUG'] ?? in_array($_SERVER['APP_ENV'], ['dev', 'test']);
```

This way you can't accidentally enable the `debug` option while using the `lambda` environment.

You now just need to configure your `serverless.yaml` to set the `APP_ENV` environment variable.

```yaml
provider:
  # [...]
  environment:
    APP_ENV: lambda
```

## Configure caching

One of the biggest differences of lambda compared to a classical hosting environments is that you can't write to disk directly.

If you followed the [bref symfony documentation], you modified your `Kernel.php` as an easy solution… revert that.
We are going to configure it more granular to get better performance through deploying cache.

Symfony will actually run on a read-only filesystem (if you warm and deploy the cache)
but not all caches are warmed completely and silently fail to write during runtime.

Luckily, all caches, that aren't fully warmed, are classical key value cache pools which are configurable.

```yaml
# config/packages/lambda/cache.yaml
framework:
    cache:
        # write all caches into the filesystem
        system: cache.adapter.filesystem # instead of cache.adapter.system
        app: cache.adapter.filesystem # this is the default but i like to be explicit here

        # in lambda, /tmp is writable although limited to the this lambda instance 
        directory: '/tmp/pools'
```  

This will make all symfony cache pools write into `/tmp/pools` instead of `var/cache/{environment}/pools`.
Note that twig, translations and doctrine will still be in `var/cache/{environment}`
but those caches aren't generated at runtime if you warm the cache so that is fine.

You'll need to be aware of a few things though:

- The `/tmp` directory is limited to the [lambda execution context] so it isn't shared between concurrent executions. 
- The `system` cache contains code related things like validator, serializer, annotation and property metadata caches.
  This cache must be cleared after deploying new code which will luckily happen automatically
  thanks to lambda destroying the execution context after a code update.
- The `app` cache is for your application and only you know what is in there if you use it at all.
  It may be necessary to configure an external caching service for this if you need it to be consistent across contexts.
- On a [cold start], the cache will be empty.
  I [experimented with deploying a warmed pools folder] and found that it is actually slower to copy the cache
  than to just start with the system cache cold but that is highly dependent on the application.

Now if you deploy your application, you'll need to warm the cache with `app/console cache:warmup -e lambda`
and you'll also need to make sure that you deploy the cache folder. I recommend the following `serverless.yaml` config.

```yaml
# serverless.yaml
provider:
  # [...]
  environment:
    APP_ENV: lambda
  
package:
  exclude:
    # [...]
    - 'var/**'
    - '!var/cache/${self:provider.environment.APP_ENV}/**'
```

If you don't like this solution because the cache will be cold…
I have considered [a lot of cache deploying solutions] and think this is the best compromise between easy and performance
but your mileage may vary depending on your project so if you need to optimize, take a look and experiment.

There is also [an issue open in the symfony project] to solve the read-only cache problem but it is stalling a lot
but if you are lucky, it may already be solved in the future so take a look there too.

## Configure logging

You can't use log files so you'll need an external service for this.

The easiest solution is to just write all errors to `php://stderr` which lambda will automatically write into CloudWatch.

```yaml
# config/packages/lambda/monolog.yaml
monolog:
    handlers:
        main:
            type: stream
            path: "php://stderr"
            level: debug # info, notice, warning or error but I keep it at debug to start out
```

And you are done. To access your logs you can go through the aws console to your lambda function and just click on invocations.
You can even use `serverless logs -f [function name]` to access them quickly.

## Configure assets (and distribution)

Newer symfony version come with [Encore] which is basically [Webpack] and that is awesome because we need it.

Your static files will all be build into `public/build/**` So we need to upload them into an s3 bucket.
You can follow my guide on how to setup a [asset distribution on a serverless multipage application]
but I have a few additions for symfony.

You should use a custom domain so you can work around the limitation that Cloudfront can't pass the HOST header as `X-Forwarded-Host`.
I show you how I configured it but please go though [asset distribution on a serverless multipage application] first.

```yaml
custom:
  # these are some settings that I keep here that change based on environment
  # consider everything under environment a config file
  environment:
    # you need to register a certificate within aws.
    # Use a wildcard domain with *.example.com and example.com to easily deploy multiple environments. 
    # https://bref.sh/docs/websites.html#setting-up-a-domain-name
    domain:
      current: ${self:custom.environment.domain.${opt:stage, self:provider.stage}, self:custom.environment.domain.default}
      default:
        name: '${opt:stage, self:provider.stage}.example.com'
        certificate: 'arn:aws:acm:us-east-1:012345678901:certificate/61d153aa-92d7-11ea-bb37-0242ac130002'
        cdnPriceClass: PriceClass_100
      production:
        name: 'example.com'
        certificate: 'arn:aws:acm:us-east-1:012345678901:certificate/61d153aa-92d7-11ea-bb37-0242ac130002'
        cdnPriceClass: PriceClass_100

package:
  exclude:
    # the function does not need the frontend asset resources except for the manifest for mapping reasons
    - 'node_modules/**'
    - 'public/**'
    - '!public/build/manifest.json'
    - '!public/index.php'
    # [...]
  # this exclude is useless as it is just for node modules which are excluded entirely
  # https://serverless.com/framework/docs/providers/aws/guide/packaging#development-dependencies
  excludeDevDependencies: false

provider:
  # [...]
  environment:
    # the application will run behind CloudFront so we'll need to trust any incoming ip
    TRUSTED_PROXIES: 'REMOTE_ADDR'
    # https://www.skeletonscribe.net/2013/05/practical-http-host-header-attacks.html'
    # TRUSTED_HOSTS is a regular expression so you'll need to replace '.' with '\.' and add '^' and '$'
    TRUSTED_HOSTS: !Join ['\.', !Split ['.', '^${self:custom.environment.domain.current.name}$']]
  # [...]

resources:
  Resources:
    DistributionConfig: # https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_DistributionConfig.html
      Enabled: true
      PriceClass: ${self:custom.environment.domain.current.cdnPriceClass}
      HttpVersion: http2
      Aliases:
        - '${self:custom.environment.domain.current.name}'
      ViewerCertificate:
        AcmCertificateArn: ${self:custom.environment.domain.current.certificate}
        # https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/distribution-web-values-specify.html#DownloadDistValuesClientsSupported
        SslSupportMethod: sni-only
        MinimumProtocolVersion: TLSv1.2_2018

      # [...] keep the rest of the original article

      Origins: # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-origin.html
        - Id: Website
          DomainName: !Join ['.', [!Ref HttpApi, 'execute-api', !Ref AWS::Region, 'amazonaws.com']]
          CustomOriginConfig:
            OriginProtocolPolicy: https-only
          OriginCustomHeaders:
            # CloudFront does not set X-Forwarded headers except for X-Forwarded-For
            - {HeaderName: X-Forwarded-Host, HeaderValue: '${self:custom.environment.domain.current.name}'}
            - {HeaderName: X-Forwarded-Proto, HeaderValue: 'https'}
            - {HeaderName: X-Forwarded-Port, HeaderValue: '443'}

      # [...] keep the rest of the original article 
```

You need to configure your application to accept the `X-Forwared-Host` header.

```diff
// public/index.php
- Request::setTrustedProxies(explode(',', $trustedProxies), Request::HEADER_X_FORWARDED_ALL ^ Request::HEADER_X_FORWARDED_HOST);
+ Request::setTrustedProxies(explode(',', $trustedProxies), Request::HEADER_X_FORWARDED_ALL);
```

And you are done.

You can now deploy your code as well as your assets:

```sh
sls deploy # deploy your code and infrastructure
sls s3deploy # deploy your assets (you can do that before the code update after the first deploy)
```

You should also take a look at the [bref documentation on website hosting] since it has pictures
and explains other ways that you may be interested in.

## Configure sessions (and the aws-sdk)

By default, php will write sessions into `/tmp` so it might appear to work at first but you session will randomly
get lost because, just as the cache, it is limited to 1 lambda context.

To solve this, we need to use an external service to store session.
Luckily, the official aws-sdk comes with a php session handler that stores them in [DynamoDB]
which is the most scalable database aws has to offer so this should be _the solution_ for every php project
that needs classical sessions.

### install the [aws-sdk]

First of, install the [aws-sdk] and the corresponding symfony bundle to save yourself some configuration.

```sh
composer require aws/aws-sdk-php aws/aws-sdk-php-symfony
```

Symfony flex will automatically configure the bundle but we will change those configurations
so that the bundle is only loaded in our `lambda` environment. 

```diff
your-project/
 ├─ config/
 ├─ ├─ packages/
 ├─ ├─ ├─ lambda/
+├─ ├─ ├─ └─ aws.yaml # move this file from the directory above
-├─ ├─ └─ aws.yaml
~└─ └─ bundles.php # and also change the environment in the bundle configuration
~.env # you can remove the credentials that symfony/flex created here since those aren't needed in lambda
```

```diff
// config/bundles.php
- Aws\Symfony\AwsBundle::class => ['all' => true],
+ Aws\Symfony\AwsBundle::class => ['lambda' => true],
```

```yaml
# config/packages/lambda/aws.yaml
aws:
    # you can remove the credential config here since the aws-sdk will pick them up from running in lambda
    version: latest
    region: '%env(AWS_REGION)%' # AWS_REGION is automatically defined in lambda
    http:
        connect_timeout: 2 # this is important if you later play with vpc's as this will quickly timeout if you did something wrong
        timeout: 30 # you can probably get away with 5 seconds, but everything is better than the default (which is infinite)
        handler: '@aws.http_handler' # this allows us to configure logging

# all of these services are just to configure logging in guzzle, which is used by the aws-sdk
# but it makes understanding what's happening a lot simpler so definitely do this.
services:
    aws.http_handler:
        class: GuzzleHttp\HandlerStack
        factory: [GuzzleHttp\HandlerStack, create]
        calls: [[push, ['@aws.http_logger']]]
    
    aws.http_logger:
        class: Closure
        factory: [GuzzleHttp\Middleware, log]
        arguments: ['@logger', '@aws.log_formatter']
        tags: [{name: monolog.logger, channel: aws}]

    aws.log_formatter:
        class: GuzzleHttp\MessageFormatter
        arguments: ['{method} {uri} HTTP/{version} {code}']
```

### actually configuring the session handler

Now that we have configured the aws sdk so that the DynamoDB client is available with just `@aws.dynamodb`.

Symfony allows us to easily change the standard php session handler with just some configuration:

```yaml
# config/packages/lambda/framework.yaml
framework:
    session:
        handler_id: app.dynamodb_session_handler

services:
    app.dynamodb_session_handler:
        class: Aws\DynamoDb\SessionHandler
        factory: [Aws\DynamoDb\SessionHandler, fromClient]
        arguments:
            - '@aws.dynamodb'
            -   table_name: '%env(resolve:SESSION_TABLE)%'
                locking: false
```

Now we also need the DynamoDB Table and define the `SESSION_TABLE` environment variable.
We can do both easily in the serverless configuration.

```yaml
# serverless.yaml
provider:
  # [...]
  environment:
    APP_ENV: lambda
    SESSION_TABLE: !Ref SessionTable

  # [...]
  iamRoleStatements:
    - Effect: Allow
      Resource: !GetAtt SessionTable.Arn
      # https://docs.aws.amazon.com/IAM/latest/UserGuide/list_amazondynamodb.html
      # I don't allow Scan because I don't do manual garbage collection, DynamoDB will do that automatically using TTL
      Action: dynamodb:*Item

# [...]
resources:
  Resources:
    SessionTable:
      Type: AWS::DynamoDB::Table # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/AWS_DynamoDB.html
      Properties:
        TableName: '${self:service}-${opt:stage, self:provider.stage}-sessions'
        BillingMode: PAY_PER_REQUEST
        AttributeDefinitions:
          - {AttributeName: id, AttributeType: S}
        KeySchema:
          - {AttributeName: id, KeyType: HASH}
        TimeToLiveSpecification:
          {AttributeName: expires, Enabled: true}
```

And now you have working sessions.

Some of the documentation of the session handler that comes with the aws-sdk states
that you need to configure garbage collection.
This isn't true anymore since we configured the [TimeToLiveSpecification] which automatically cleans up
and the best thing about that is that you aren't even charged for the delete operations.

## Configure mailing

AWS has [SES] to send emails. This service is region limited. Take a look at the [region-table].

If you haven't done anything yet, your account will be in sandbox mode by default.
This means you can't send emails to anyone who hasn't verified that they want emails.
The easiest way is to [verify a domain] (like your work domain) but you can also [verify a single email].
Later, you'll have to request a limit increase so you can send emails to everyone
but you'll still need to verify an email or domain to send _FROM_.

Now here is the next problem: There is a [symfony/amazon-mailer] but it currently does not support
to assume the role of the current lambda function.
[That feature is now added](https://github.com/symfony/symfony/pull/35992) but only in the dev version of `5.1`
so we are going to install that. This works even in symfony 4.4 so don't worry there.

For that you'll need to modify your `composer.json` a bit since symfony/flex will prevent the installation
of newer version of symfony which normally is a good thing to prevent a version mess… but in our case we want that.

```diff
"extra": {
    "symfony": {
        "allow-contrib": false,
-       "require": "4.4.*"
+       "require": "4.4.*||v5.1.0-BETA1"
    }
}
```

Now you can install the newest beta version of the [symfony/amazon-mailer].
Since beta versions aren't implicitly installed, you don't have to worry about accidentally installing other `5.1` packages.
For the future, [there is an issue](https://github.com/symfony/flex/issues/619) addressing the problem of installing none-beta versions.

```
composer require 'symfony/amazon-mailer:v5.0.1-BETA1' async-aws/ses
```

This will install [`v5.1.0-BETA1`](https://github.com/symfony/amazon-mailer/releases/tag/v5.1.0-BETA1)
and the [async-aws] implementation of the ses client which the ses factory 
[will use if available](https://github.com/symfony/amazon-mailer/blob/v5.1.0-BETA1/Transport/SesTransportFactory.php#L37)
which is capable of picking up the credentials from the lambda environment.

Now you just need to configure your `serverless.yaml` to set the `MAILER_DSN` and the iam permissions.

```yaml
# serverless.yaml
provider:
  # [...]
  environment:
    # [...]
    MAILER_DSN: 'ses://default'

  # [...]
  iamRoleStatements:
    # allow sending emails
    # https://docs.aws.amazon.com/de_de/ses/latest/DeveloperGuide/control-user-access.html#iam-and-ses
    - Effect: Allow
      Resource: '*' # allow sending with every available identity
      # https://docs.aws.amazon.com/IAM/latest/UserGuide/list_amazonses.html
      Action: ses:Send*
```

And if you have a verified domain or email, you should now be able to send emails.

## Configure doctrine

There is again a good [bref documentation on databases] and I might be biased but I'm going to use [Aurora Serverless]
(in MySQL 5.6 compatible mode) with my own [Nemo64/dbal-rds-data] driver. Here is why:

Aurora Serverless does cost at least $50.40 per month if run continuously + storage, but it saves you more money than you think.

- Aurora Serverless can auto pause. This is kind of useless in production, because it takes up to a minute to boot,
  but it is really useful in dev environments.
- The rds data api saves you the trouble of running your lambda in a VPC
  - this saves you the trouble of learning how to setup a VPC (although you probably can't avoid it in your career)
  - it saves you of needing a NAT gateway wich costs $34.56 per month for 1 instance
    which then is also a single point of failure so you might want multiple gateways for reliability.
- You get seemless auto scaling if your applications grows which is especially interesting if your application is small.
    
There are some downsides of using Aurora Serverless but if you are using the doctrine orm,
then you probably won't notice them and you can switch to another database later if needed.

Note that the rds-data api is again fairly [region limited](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/data-api.html#data-api.regions).
If you want to host anywhere else, you'll need to familiarise yourself with VPC's to securely set that up.

Most of the documentation is already available in the Readme of [Nemo64/dbal-rds-data] but I'm repeating this
specifically for this symfony setup here.

```sh
composer require nemo64/dbal-rds-data
```

```yaml
# config/packages/lambda/doctrine.yaml
doctrine:
    dbal:
        # the url can override the driver class
        # but I can't define this driver in the url which is why i made it the default
        # Doctrine\DBAL\DriverManager::parseDatabaseUrlScheme
        driver_class: Nemo64\DbalRdsData\RdsDataDriver
# keep the rest of your doctrine.yaml from the prod environment
```

```yaml
# serverless.yaml
provider:
  # [...]
  environment:
    # [...]
    DATABASE_URL: !Join
      - ''
      - - '//' # rds-data is set to default because custom drivers can't be named in a way that they can be used here
        - !Ref AWS::Region # the hostname is the region
        - '/${opt:stage, self:provider.stage}'
        - '?driverOptions[resourceArn]='
        - !Join [':', ['arn:aws:rds', !Ref AWS::Region, !Ref AWS::AccountId, 'cluster', !Ref Database]]
        - '&driverOptions[secretArn]='
        - !Ref DatabaseSecret
  
  # [...]
  iamRoleStatements:
    - Effect: Allow
      Resource: '*' # it isn't supported to limit this
      # https://docs.aws.amazon.com/IAM/latest/UserGuide/list_amazonrdsdataapi.html
      Action: rds-data:*
    # this rds-data endpoint will use the same identity to get the secret 
    - Effect: Allow
      Resource: !Ref DatabaseSecret
      # https://docs.aws.amazon.com/IAM/latest/UserGuide/list_awssecretsmanager.html
      Action: secretsmanager:GetSecretValue

# [...]
resources:
  Resources:
      # Make sure that there is a default VPC in your account.
      # https://console.aws.amazon.com/vpc/home#vpcs:isDefault=true
      # If not, click "Actions" > "Create Default VPC"
      # While your applications doesn't need it, the database must still be provisioned into a VPC so use the default. 
      Database:
        Type: AWS::RDS::DBCluster # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-rds-dbcluster.html
        Properties:
          Engine: aurora
          EngineMode: serverless
          EnableHttpEndpoint: true # this is the important part
          DatabaseName: '${opt:stage, self:provider.stage}'
          MasterUsername: !Join ['', ['{{resolve:secretsmanager:', !Ref DatabaseSecret, ':SecretString:username}}']]
          MasterUserPassword: !Join ['', ['{{resolve:secretsmanager:', !Ref DatabaseSecret, ':SecretString:password}}']]
          # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-rds-dbcluster-scalingconfiguration.html
          ScalingConfiguration: {MinCapacity: 1, MaxCapactiy: 2, AutoPause: true}
      DatabaseSecret:
        Type: AWS::SecretsManager::Secret # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-secretsmanager-secret.html
        Properties:
          GenerateSecretString:
            SecretStringTemplate: '{"username": "admin"}'
            GenerateStringKey: "password"
            PasswordLength: 41 # max length of a mysql password
            ExcludeCharacters: '"@/\'
      DatabaseSecretAttachment:
        Type: AWS::SecretsManager::SecretTargetAttachment # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-secretsmanager-secrettargetattachment.html
        Properties:
          SecretId: !Ref DatabaseSecret
          TargetId: !Ref Database
          TargetType: AWS::RDS::DBCluster
```

And now you have application has a database.
You can now run the usual commands to create the schema but you'll have to do that within your lambda so:

```sh
sls invoke -f console -d '{"cli": "doctrine:migrations:migrate --no-interaction"}'
```

You can also use the [bref cli command] which has a much nicer output but you'll need to pass the region and the full lambda name.

## Final words

That's it for the moment.
There are still a few things I haven't touched and a lot I probably haven't even discovered.
I'll probably keep this post update just as documentation for myself.

I want to thank [Matthieu](https://mnapoli.fr/) for the unbelievable amount of work he continues to put into [bref]
and also [Tobias](https://tnyholm.se/) because he somehow gets involved in nearly all issue I open related to symfony and aws.


[bref]: https://bref.sh/
[bref documentation]: https://bref.sh/docs/
[create an environment]: https://symfony.com/doc/4.1/configuration/environments.html#creating-a-new-environment
[bref symfony documentation]: https://bref.sh/docs/frameworks/symfony.html
[lambda execution context]: https://docs.aws.amazon.com/lambda/latest/dg/runtimes-context.html
[cold start]: https://dashbird.io/knowledge-base/aws-lambda/cold-starts/
[experimented with deploying a warmed pools folder]: https://github.com/brefphp/symfony-bridge/issues/21#issuecomment-612942058
[a lot of cache deploying solutions]: https://github.com/brefphp/symfony-bridge/issues/31#issuecomment-615917906
[an issue open in the symfony project]: https://github.com/symfony/symfony/issues/23354
[Encore]: https://symfony.com/doc/current/frontend/encore/installation.html
[Webpack]: https://webpack.js.org/
[asset distribution on a serverless multipage application]: /asset-distribution-on-a-aws-serverless-multipage-application
[bref documentation on website hosting]: https://bref.sh/docs/websites.html
[DynamoDB]: https://aws.amazon.com/dynamodb/
[aws-sdk]: https://github.com/aws/aws-sdk-php
[TimeToLiveSpecification]: https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/howitworks-ttl.html
[SES]: https://aws.amazon.com/ses/
[region-table]: https://aws.amazon.com/about-aws/global-infrastructure/regional-product-services/
[verify a domain]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-domain-procedure.html
[verify a single email]: https://docs.aws.amazon.com/ses/latest/DeveloperGuide/verify-email-addresses-procedure.html
[symfony/amazon-mailer]: https://github.com/symfony/amazon-mailer
[async-aws]: https://async-aws.com/
[bref documentation on databases]: https://bref.sh/docs/environment/database.html
[Aurora Serverless]: https://aws.amazon.com/de/rds/aurora/serverless/
[Nemo64/dbal-rds-data]: https://github.com/Nemo64/dbal-rds-data
[bref cli command]: https://bref.sh/docs/runtimes/console.html#usage
