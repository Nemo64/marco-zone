---
title:       Static resource distribution on a aws serverless multipage application
description: Hosting a multipage application has never been simpler but aws and serverless aren't build for that use case. But, when configured correctly, it is actually a very powerful hosting setup. 
categories:
    - AWS
    - serverless
date:        2020-04-05 21:00:00 +0200
lastmod:     2020-04-05 21:00:00 +0200
---

## Basic setup

I assume you use [serverless] already because i'll be using a serverless plugin.
You can go without it but it will increase complexity.

## Asset S3 Bucket

You'll of course need a Bucket to upload you assets to.
Just define a simple Bucket like this:

```yaml
resources:
  Resources:
    # The S3 bucket that stores our static assets
    Assets:
      Type: AWS::S3::Bucket
```

You actually don't need any properties.
The name will be automatically given based on your stack name + some hash to avoid collisions.
Now you'll need to upload some files.

## Deploy files to the S3 Bucket

You can create a manual workflow but i prefer the [serverless-s3-deploy] plugin
because it allows to configure what files you'll deploy within the serverless.yaml file.

```yaml
custom:
  # https://github.com/funkybob/serverless-s3-deploy#readme
  assets:
    targets:
      - bucket: !Ref Assets
        files:
          # deploy stuff from a public/ folder
          - {source: 'public', globs: 'build/*.*', headers: {CacheControl: 'public, max-age=31536000, immutable'}}
          - {source: 'public', globs: 'favicon.ico', headers: {CacheControl: 'public, max-age=3600'}}
          - {source: 'public', globs: 'robots.txt', headers: {CacheControl: 'public, max-age=300'}}
```

You can the deploy all assets using `serverless s3deply` which will then go through all your rules.

If possible, all files should be a checksum so you can deploy your new assets before starting 
the `serverless deploy` process and also to cache them forever. 
If you use webpack (which you should), you can [configure output filenames] to be `[contenthash]` and `[chunkhash]`.

There are some files that you can't easily hash, like the `robots.txt` file
but in that case it isn't a problem that the file is out-of-sync for a few seconds.

[serverless-s3-deploy] sadly does not provide a nice way of removing outdated assets.
You can set `empty: true` but it deletes the entire bucket before uploading the new files
which means you site may be missing some assets before your `serverless deploy` ran though.
I need to find or develop a good solution for that at some point.

### Continues Integration

If you build an automated deployment process you'll want to deploy assets before you deploy your code.

```yaml
# deploy assets first to ensure new assets are available before the code is.
# This, however, will fail on the first deployment because the bucket isn't deployed yet
# so there needs to be a backup after the code deployment to make sure it always runs smoothly.
- sls s3deploy --stage=$BITBUCKET_DEPLOYMENT_ENVIRONMENT --verbose || ASSET_DEPLOYMENT_FAILED=$true
- sls deploy --stage=$BITBUCKET_DEPLOYMENT_ENVIRONMENT --conceal
- if [ $ASSET_DEPLOYMENT_FAILED ]; then sls s3deploy --stage=$BITBUCKET_DEPLOYMENT_ENVIRONMENT --verbose; fi
```

## Distribution (CDN)

You now need a way to bring everything together. Your html delivery probably runs on an ApiGateway.

A [CloudFront] Distribution is a good choice to bring everything together under 1 domain.
Your user will only have to resolve 1 hostname and only connect to 1 endpoint which also supports http2
while you use multiple services in the background to best fit your need.

```yaml
resources:
  Resources:
    # [...]

    # The main CDN
    Distribution:
      # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudfront-distribution.html
      Type: AWS::CloudFront::Distribution
      Properties:
        DistributionConfig: # https://docs.aws.amazon.com/cloudfront/latest/APIReference/API_DistributionConfig.html
          Enabled: true
          PriceClass: PriceClass_100
          HttpVersion: http2
          Origins: # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-origin.html
    
            - Id: Assets
              DomainName: !GetAtt Assets.RegionalDomainName
              S3OriginConfig:
                OriginAccessIdentity: !Join ['/', ['origin-access-identity', 'cloudfront', !Ref DistributionIdentity]]
    
            # the api gateway for your normal http requests (depending on if you use the http api or the rest api)
            - Id: Website
              DomainName: !Join ['.', [!Ref HttpApi, 'execute-api', !Ref AWS::Region, 'amazonaws.com']]
              # DomainName: !Join ['.', [!Ref ApiGatewayRestApi, 'execute-api', !Ref AWS::Region, 'amazonaws.com']]
              # OriginPath: '/${opt:stage, "dev"}'
              CustomOriginConfig:
                OriginProtocolPolicy: https-only
    
          # Behaviors how CloudFront forwards traffic
          # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-cachebehavior.html
          CacheBehaviors:
    
            # catches build/*.js but also favicon.ico, robots.txt etc...
            # this will also prevent some annoying requests hitting your lambda function 
            - PathPattern: '*.*' 
              TargetOriginId: Assets
              AllowedMethods: [GET, HEAD]
              ForwardedValues:
                QueryString: false
              ViewerProtocolPolicy: redirect-to-https
              Compress: true
    
          # everything else should hit the website
          DefaultCacheBehavior:
            AllowedMethods: [GET, HEAD, OPTIONS, PUT, PATCH, POST, DELETE]
            TargetOriginId: Website
            ForwardedValues:
              QueryString: true
              Cookies: {Forward: all}
              Headers: [] # figure out which headers you need
            ViewerProtocolPolicy: redirect-to-https
            Compress: true
            # caching behavior for your normal sites
            DefaultTTL: 0
            MinTTL: 0
            MaxTTL: 0
    
    # Create an identity so access can be limited to the cdn
    DistributionIdentity:
      # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-resource-cloudfront-cloudfrontoriginaccessidentity.html
      Type: AWS::CloudFront::CloudFrontOriginAccessIdentity 
      Properties:
        CloudFrontOriginAccessIdentityConfig:
          Comment: "${self:service}-${opt:stage, 'dev'} distribution"
```

Now you need to configure your s3 bucket so that the cdn can access them.

```yaml
resources:
  Resources:
    # [...]
    AssetsBucketPolicy:
      # https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-s3-policy.html
      Type: AWS::S3::BucketPolicy 
      Properties:
        Bucket: !Ref Assets
        PolicyDocument:
          Statement:
            - Effect: Allow
              Action: s3:GetObject
              Resource: !Join ['/', [!GetAtt Assets.Arn, '*']]
              Principal:
                CanonicalUser: !GetAtt DistributionIdentity.S3CanonicalUserId
```

Now just run `serverless deploy` and expect this to take a few minutes on the first deploy.

To make it simpler to find the cloudfront domain, I recommend you define an output to show it:

```yaml
resources:
  Resources:
    # [...]
  Outputs:
    DistributionDomain:
      Description: The domain of the CDN
      Value: !GetAtt Distribution.DomainName
```

It'll then appear when you run `sls info -v`.

Of course, you'll want to configure a domain for your Distribution.
Doing that correctly is actually worth a guide within itself (especially with correctly proxying it to the lambda)
But the [bref documentation on a CDN domain] is a good starting point. 

## Other resources

- the [bref documentation] on that topic
- the aws template for [StaticS3CloudFront] configuration 

[serverless]: https://serverless.com/
[serverless-s3-deploy]: https://github.com/funkybob/serverless-s3-deploy
[configure output filenames]: https://webpack.js.org/guides/caching/#output-filenames
[CloudFront]: https://aws.amazon.com/cloudfront/
[creating a domain for HTTP lambdas]: https://bref.sh/docs/environment/custom-domains.html#custom-domains-for-http-lambdas
[Aliases]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-distributionconfig.html#cfn-cloudfront-distribution-distributionconfig-aliases
[ViewerCertificate]: https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/aws-properties-cloudfront-distribution-distributionconfig.html#cfn-cloudfront-distribution-distributionconfig-viewercertificate
[bref documentation on a CDN domain]: https://bref.sh/docs/websites.html#setting-up-a-domain-name
[bref documentation]: https://bref.sh/docs/websites.html
[StaticS3CloudFront]: https://github.com/awslabs/aws-cloudformation-templates/blob/5c66bbfaec08313fcfee48b49ce6ba0a38f6bb1a/community/solutions/StaticS3CloudFront.yml
