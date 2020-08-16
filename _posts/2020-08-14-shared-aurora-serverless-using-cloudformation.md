---
title: Share an Aurora Serveless between services using CloudFormation 
description: >-
    Securely set up RDS Aurora Serverless and use custom resources in CloudFormation
    to create additional databases and users across multiple stages or even services.
categories:
    - AWS
    - serverless
    - MySQL
    - Software-Development
date: 2020-08-16 17:17:00 +0200
image: assets/aws-aurora.png
---

## Why would you even want to share a Database?

Everything that allocates RAM and CPU on AWS is quiet expensive.
Although it is called Aurora _Serverless_, it still allocates a server that just auto scales very well.

Aurora is capable of scaling down to 0 compute, but the wake up process is way too slow to use this in production,
and it's also quiet annoying in dev environment.

Then, if you use microservices, it is even harder to justify an entire database for a service that idles most of the time.

MySQL has a solution build in: databases, which act like namespaces.
You can use a single MySQL server for multiple purposes by just creating multiple databases and users.
That sounds obvious but managing it is traditionally an annoying manual process and AWS has no way of declaratively doing so.

So let's do something about it.

I want all infrastructure declaration in CloudFormation.
Every manual step is 1 step too much.

## Basic structure

{% responsive_image path: 'assets/aws-aurora-shared.png' %}

I'm going to use serverless to deploy the infrastructure, but most of my examples will be pure CloudFormation
so you should be able to get along if you us other tools. 

I'm going to use 2 kinds of cloudformation stacks

1. A shared stack (`serverless-shared.yml`) which i'm going to deploy once per AWS account.
   It contains the Database Server, the VPC configuration and a few Lambda functions that help us in creating additional resources.
2. The application stack (`serverless.yml`) which I use as an example service and defines a MySQL database
   and potentially multiple MySQL users with different privileges.

## Prepare serverless

You can skip this if you don't use serverless, but here is the first part of my `serverless-shared.yml`.
Note the `variableSyntax` definition. This allows me to use the `!Sub` function in a serverless file,
which would normally collide with the serverless variable syntax.  

```yaml
# serverless-shared.yml
service: shared

provider:
  name: aws
  region: eu-west-1 
  stage: ${opt:stage, 'global'} # generic stage name to indicate that this is not targeted at dev/prod environments
  # Allow using CloudFormation variable syntax without changing the serverless syntax
  # The differentiating factor is the capitalization of the first character
  # Upper case character means CloudFormation syntax, eg: ${AWS::Region}, ${DatabaseSecret}
  # Everything else means serverless syntax, eg: ${ssm:...}, ${self:...}
  # https://www.serverless.com/framework/docs/providers/aws/guide/variables#using-custom-variable-syntax
  variableSyntax: "\\${((?![A-Z])[ ~:a-zA-Z0-9._@'\",\\-\\/\\(\\)]+?)}"

resources:
    # CloudFormation template here
``` 

## Define a VPC

All resources in AWS have to be deployed to a VPC.
The Aurora CloudFormation template says that it's optional but in reality: it'll just deploy the database into the default VPC
and the default VPC can't be directly addressed in CloudFormation so that is a no-go.

So let's define the simplest VPC in CloudFormation possible.

```yaml
# serverless-shared.yml
Resources:
  # the simplest possible VPC with 3 Availability Zones
  VPC:
    Type: AWS::EC2::VPC
    Properties:
      CidrBlock: 10.192.0.0/16
      EnableDnsSupport: true
      EnableDnsHostnames: true
      Tags:
        - {Key: Name, Value: !Ref AWS::StackName} # the console will display this as the name
  
  Subnet1:
    Type: AWS::EC2::Subnet
    Properties: {CidrBlock: 10.192.0.0/20, AvailabilityZone: !Select [0, !GetAZs ''], VpcId: !Ref VPC}
  Subnet2:
    Type: AWS::EC2::Subnet
    Properties: {CidrBlock: 10.192.16.0/20, AvailabilityZone: !Select [1, !GetAZs ''], VpcId: !Ref VPC}
  Subnet3:
    Type: AWS::EC2::Subnet
    Properties: {CidrBlock: 10.192.32.0/20, AvailabilityZone: !Select [2, !GetAZs ''], VpcId: !Ref VPC}
  
  # subnet and security groups for the database later 
  DatabaseSubnetGroup:
    Type: AWS::RDS::DBSubnetGroup
    Properties: 
      DBSubnetGroupDescription: Database
      SubnetIds: [!Ref Subnet1, !Ref Subnet2, !Ref Subnet3]
  DatabaseSecurityGroup:
    Type: AWS::EC2::SecurityGroup
    Properties:
      GroupDescription: Database
      VpcId: !Ref VPC
      SecurityGroupIngress:
        - {CidrIp: !GetAtt VPC.CidrBlock, FromPort: 3306, ToPort: 3306, IpProtocol: tcp}
``` 

This is a simple VPC with 3 subnets to cover 3 Availability-Zones. 

Don't worry about evenly covering Availability-Zones, AWS will randomly allocate them to your AWS Account,
so it is perfectly fine to always use the first few Zones.
But you definitely want at least 3 to take advantage of automatic failovers.

I then also define the subnet group that we later use for the actual database.

## Define the Database Server

{% raw %}
```yaml
# serverless-shared.yml
Resources:
  # [...]
  DatabaseSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '/${AWS::StackName}/database/root'
      GenerateSecretString:
        SecretStringTemplate: '{"username": "root"}'
        GenerateStringKey: "password"
        ExcludeCharacters: '"@/\'
  DatabaseServer:
    Type: AWS::RDS::DBCluster
    Properties:
      Engine: aurora-mysql # aurora = mysql 5.6, aurora-mysql = mysql 5.7
      EngineMode: serverless
      EnableHttpEndpoint: true
      MasterUsername: !Sub '{{resolve:secretsmanager:${DatabaseSecret}:SecretString:username}}'
      MasterUserPassword: !Sub '{{resolve:secretsmanager:${DatabaseSecret}:SecretString:password}}'
      BackupRetentionPeriod: 10 # days
      ScalingConfiguration: {MinCapacity: 1, MaxCapacity: 2, AutoPause: true}
      DBSubnetGroupName: !Ref DatabaseSubnetGroup
      VpcSecurityGroupIds: [!GetAtt DatabaseSecurityGroup.GroupId]
  DatabaseSecretAttachment:
    Type: AWS::SecretsManager::SecretTargetAttachment
    Properties:
      SecretId: !Ref DatabaseSecret
      TargetId: !Ref DatabaseServer
      TargetType: AWS::RDS::DBCluster

Outputs:
  DatabaseServer:
    Description: The Database Server Arn
    Value: !Sub 'arn:${AWS::Partition}:rds:${AWS::Region}:${AWS::AccountId}:cluster:${DatabaseServer}'
    Export: {Name: !Sub '${AWS::StackName}-database-server'}
```
{% endraw %}

Let's go though it.

1. Define a Secret to store the credentials of the master user and generate it's password.
2. Define the Database Server. An Aurora serverless in mysql 5.7 mode.
   Aurora usually brings new features to 5.6 first, but 5.7 allows longer usernames (32 chars vs 16)
   and longer indexes which results in no error when trying to index a `VARCHAR(255)` field in utf8mb4 mode.
   Those 2 reasons
   [resolve](https://github.com/DamienHarper/auditor-bundle/issues/178)
   [some](https://github.com/symfony/symfony/issues/37116)
   [headaches](https://github.com/doctrine/dbal/issues/3419),
   so I'd stick with 5.7 unless you have a good reason not to.
   Also [JSON columns](https://www.mysqltutorial.org/mysql-json/).
3. I attach the secret to the Database which will add a few fields like `host` to it which is nice,
   because it means that one only needs to read the secret and has all information to connect to the database. 

The secret content will look like this in the end:

```json
{
  "password": "RandomPassword123!",
  "engine": "mysql",
  "port": 3306,
  "host": "stack-name-cluster-name.cluster-abcdabcdabcda.eu-west-1.rds.amazonaws.com",
  "username": "root"
}
```

Note that the secret manager costs [~40 cents per month](https://aws.amazon.com/secrets-manager/pricing/)
for managing this secret but we'll put that to good use in the next step.

## Implement password rotation

This is a feature of the secret manager that is historically annoying to use,
even though it is the main selling feature of the SecretManager.
However, CloudFormation recently got a new transformation making this easy.

```yaml
# serverless-shared.yml
Transform:
  - AWS::SecretsManager-2020-07-23 # for the password rotation function

Resources:
  DatabaseSecretRotation:
    Type: AWS::SecretsManager::RotationSchedule
    DependsOn: [DatabaseSecretAttachment, VpcSecretManagerEndpoint]
    Properties:
      SecretId: !Ref DatabaseSecret
      RotationRules: {AutomaticallyAfterDays: 30}
      HostedRotationLambda:
        RotationType: MySQLSingleUser
        RotationLambdaName: !Sub '${AWS::StackName}-database-secret-rotation'
        VpcSecurityGroupIds: !GetAtt VPC.DefaultSecurityGroup
        VpcSubnetIds: !Join [',', [!Ref Subnet1, !Ref Subnet2, !Ref Subnet3]]
  # VPC endpoint that will enable the rotation Lambda to make api calls to Secrets Manager
  VpcSecretManagerEndpoint:
    Type: AWS::EC2::VPCEndpoint
    Properties:
      SubnetIds: [!Ref Subnet1, !Ref Subnet2, !Ref Subnet3]
      SecurityGroupIds: [!GetAtt VPC.DefaultSecurityGroup]
      VpcEndpointType: Interface
      ServiceName: !Sub 'com.amazonaws.${AWS::Region}.secretsmanager'
      PrivateDnsEnabled: true
      VpcId: !Ref VPC

Outputs:
  DatabaseSecretRotationLambda:
    Description: Secret Rotation Lambda Arn
    Value: !GetAtt DatabaseSecretRotationHostedRotationLambda.Outputs.RotationLambdaARN
    Export: {Name: !Sub '${AWS::StackName}-database-secret-rotation-lambda'}
```

Now, your MySQL password will now rotate every 30 days and give you peace of mind
that even if you leak information, it rotates at some point.
Not that that makes a big difference since the database is in a VPC isolated from the outside world but still.

The Transformation will create a sub stack that defines a lambda function that will do the heavy lifting.
This function is a python function provided by AWS that will use a TCP connection to the database which is why
we have to define the VPC. But a function running in our VPC has no internet access,
so we have to bring the SecretManager into the VPC which is the reason for the VPC endpoint. 

I also output the lambda arn so we can use it later in different stacks and don't have to have multiple rotation lambdas.

Also note that I make the Rotation explicitly depending on the `DatabaseSecretAttachment` and `VpcSecretManagerEndpoint`.
Normally, CloudFormation figures out the order on it's own based on `!Ref`erences, but the SecretRotation has no
property dependency on either the Attachment nor the Endpoint so, to be safe, I declare it. 

## Implement custom resources

This is the most interesting part.

CloudFormation only sets up the initial database server but all further steps normally have to be done manually,
but we can do better and create custom resources in CloudFormation to create databases and users using CloudFormation.

### Create a database custom resource

Let's look at the `serverless.yml` of the consuming service first.

```yaml
# serverless.yml
Resources:
  Database:
    Type: Custom::Database
    Properties:
      ServiceToken: !ImportValue 'shared-global-database-service-token'
      Name: !Ref AWS::StackName
```

This is how I want to define additional database in different stacks.
I just define how I want them to be named and that's it.
In this case, I just use the stack name itself.

Custom resources always have a `ServiceToken` which is a reference to the lambda that handles them,
so let's implement that resource in the shared stack:

```yaml
# serverless-shares.yml
Transform:
  - AWS::Serverless-2016-10-31 # for inline lambda function

Resources:
  DatabaseResourceLambda:
    Type: AWS::Serverless::Function
    Properties:
      Description: !Sub 'Provides a custom CloudFormation resource to create MySQL databases in ${DatabaseServer}.'
      FunctionName: !Sub '${AWS::StackName}-database-resource'
      Handler: index.handler
      Runtime: nodejs12.x
      MemorySize: 128 # mb, this function basically just waits for the database
      Role: !GetAtt DatabaseAccessPolicy.Arn # attach role to access the database
      Environment:
        Variables:
          resourceArn: !Sub 'arn:${AWS::Partition}:rds:${AWS::Region}:${AWS::AccountId}:cluster:${DatabaseServer}'
          secretArn: !Ref DatabaseSecret
      InlineCode: |-
        const RDSDataService = new (require('aws-sdk/clients/rdsdataservice'))({apiVersion: '2018-08-01'});
        const response = require('cfn-response');
        const {resourceArn, secretArn} = process.env;

        exports.handler = async function (event, context) {
            try {
                console.log(event);
                const name = event.ResourceProperties.Name;

                if (event.RequestType === 'Delete') {
                    const sql = 'DROP DATABASE IF EXISTS `' + name + '`';
                    await RDSDataService.executeStatement({resourceArn, secretArn, sql}).promise();
                    return await response.send(event, context, response.SUCCESS);
                }

                if (name !== event.PhysicalResourceId) {
                    const sql = 'CREATE DATABASE `' + name + '`';
                    await RDSDataService.executeStatement({resourceArn, secretArn, sql}).promise();
                }

                return await response.send(event, context, response.SUCCESS, {Server: resourceArn}, name);
            } catch (error) {
                if (/^Communications link failure/.test(error.message)) {
                    throw error; // let lambda reattempt this action if aurora is paused
                }

                console.error(error);
                return await response.send(event, context, response.FAILED);
            }
        };
  DatabaseAccessPolicy:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${AWS::StackName}-${AWS::Region}-database-access-policy'
      AssumeRolePolicyDocument: {Version: '2012-10-17', Statement: [{Effect: Allow, Action: sts:AssumeRole, Principal: {Service: [lambda.amazonaws.com]}}]}
      Policies:
        - PolicyName: !Sub "${AWS::StackName}-database-access"
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              - {Effect: Allow, Action: logs:CreateLog*, Resource: !Sub 'arn:${AWS::Partition}:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AWS::StackName}*:*'}
              - {Effect: Allow, Action: logs:PutLogEvents, Resource: !Sub 'arn:${AWS::Partition}:logs:${AWS::Region}:${AWS::AccountId}:log-group:/aws/lambda/${AWS::StackName}*:*:*'}
              - {Effect: Allow, Action: rds-data:ExecuteStatement, Resource: '*'}
              - {Effect: Allow, Action: secretsmanager:GetSecretValue, Resource: !Sub 'arn:${AWS::Partition}:secretsmanager:${AWS::Region}:${AWS::AccountId}:secret:/${AWS::StackName}/database/*'}

Outputs:
  DatabaseServiceToken:
    Description: Lambda function that can be used to create a database on a database server in CloudFormation
    Value: !GetAtt DatabaseResourceLambda.Arn
    Export: {Name: !Sub '${AWS::StackName}-database-service-token'}
```

I define a lambda function purely in CloudFormation.
I could use a serverless function, but I can't declare their code inline.
This function basically has to handle 3 scenarios:

- Create: On which I execute a `CREATE DATABASE` statement.
  `event.PhysicalResourceId` will be undefined in that scenario so the statement is always executed.
  I return the database name as the `PhysicalResourceId` which allows you to use `!Ref` to get the name.
- Update: Which is the same as Create, but I look at the `event.PhysicalResourceId`
  and only execute the statement if it does not match.
- Delete: Which deletes the resource using `DROP DATABASE IF EXISTS`.
  This function is also called if the `PhysicalResourceId` changed in the "Update complete, cleanup in progress"
  stage you might have seen in CloudFormation at some point already.
  This is also why you don't have to bother with the old database during Update.
  
There are 2 more important things to note:

- You always want you lambda to respond to resource create requests,
  which is why I wrap the entire function in a `try {} catch {}` block.
  If you don't do that, you have to wait for CloudFormation to time out, which takes ~30 minutes.
  It's also good practice to just log the event so if you are stuck, so you can manually respond using the ResponseURL in the event.
- Aurora Serverless might be paused, and that is the one situation where I let the lambda fail in a controlled manner.
  The CloudFormation invoke will be handled like an event which means Lambda will retry the exectution after some time.
  If aurora is paused, I just fail and lambda will retry at which point the database is hopefully up and running.


### Create a user custom resource

Let's, again, look at the usage first:

```yaml
# serverless.yml
Resource:
  DatabaseUserSecret:
    Type: AWS::SecretsManager::Secret
    Properties:
      Name: !Sub '/shared-global/database/${AWS::StackName}'
      GenerateSecretString:
        SecretStringTemplate: !Sub '{"username": "${AWS::StackName}"}'
        GenerateStringKey: "password"
        ExcludeCharacters: '"@/\'
  DatabaseUserSecretAttachment:
    Type: AWS::SecretsManager::SecretTargetAttachment
    Properties:
      SecretId: !Ref DatabaseUserSecret
      TargetId: !ImportValue 'shared-global-database-server'
      TargetType: AWS::RDS::DBCluster
  DatabaseUser:
    Type: Custom::DatabaseUser
    DependsOn: DatabaseUserSecretAttachment
    Properties:
      ServiceToken: !ImportValue 'shared-global-database-user-service-token'
      SecretId: !Ref DatabaseUserSecret
      Privileges:
        - {Permission: ALL, Database: !Ref Database, Table: '*'}
  DatabaseUserSecretRotation:
    Type: AWS::SecretsManager::RotationSchedule
    DependsOn: DatabaseUser
    Properties:
      SecretId: !Ref DatabaseUserSecret
      RotationRules: {AutomaticallyAfterDays: 30}
      RotationLambdaARN: !ImportValue 'shared-global-database-secret-rotation-lambda'
```

Ok so there are multiple things going on here.

1. Create a secret for our new user, so we have a place to store the password.
   I use the stack name as a user name here. Note that the username im MySQL (5.7) is limited to 32 characters.
2. Attach the secret to the database which will fill in the rest of the properties,
   just like when we created the root secret.
3. Use the custom resource, that I'll show you later, to create the user with the secret.
   I also define the users privileges, so I can limit the user to the database we defined earlier.
   Feel free to create even more restricted user but remeber that any secret in the SecretManager costs 40 cents per month.
4. Define Password rotation on that user, because we now easily can.
   Just import it from the shared stack.

So now, let's define the custom resource in the shared stack:

```yaml
# serverless-shares.yml
Transform:
  - AWS::Serverless-2016-10-31 # for inline lambda function

Resources:
  DatabaseUserResourceLambda:
    Type: AWS::Serverless::Function
    Properties:
      Description: !Sub 'Provides a custom CloudFormation resource to create MySQL users in ${DatabaseServer}.'
      FunctionName: !Sub '${AWS::StackName}-database-user-resource'
      Handler: index.handler
      Runtime: nodejs12.x
      MemorySize: 128 # mb, this function basically just waits for the database
      Role: !GetAtt DatabaseAccessPolicy.Arn # attach role to access the database
      Environment:
        Variables:
          resourceArn: !Sub 'arn:${AWS::Partition}:rds:${AWS::Region}:${AWS::AccountId}:cluster:${DatabaseServer}'
          secretArn: !Ref DatabaseSecret
      InlineCode: |-
        const RDSDataService = new (require('aws-sdk/clients/rdsdataservice'))({apiVersion: '2018-08-01'});
        const SecretsManager = new (require('aws-sdk/clients/secretsmanager'))({apiVersion: '2017-10-17'});
        const response = require('cfn-response');
        const {resourceArn, secretArn} = process.env;

        exports.handler = async function (event, context) {
            try {
                console.log(event);
                const userSecretId = event.ResourceProperties.SecretId;
                const secret = await SecretsManager.getSecretValue({SecretId: userSecretId}).promise();
                const {username, password} = JSON.parse(secret.SecretString);

                if (event.RequestType === 'Delete') {
                    await executeStatement('DROP USER IF EXISTS :username', {username});
                    return await response.send(event, context, response.SUCCESS);
                }

                if (userSecretId !== event.PhysicalResourceId) {
                    await executeStatement('CREATE USER :username IDENTIFIED BY :password', {username, password});
                }

                await executeStatement('REVOKE ALL PRIVILEGES, GRANT OPTION FROM :username', {username});
                for (const {Permission, Database, Table} of event.ResourceProperties.Privileges) {
                    await executeStatement("GRANT " + Permission + " ON `" + Database + "`." + Table + " TO :username", {username});
                }

                return await response.send(event, context, response.SUCCESS, null, userSecretId);
            } catch (error) {
                if (/^Communications link failure/.test(error.message)) {
                    throw error; // let lambda reattempt this action if aurora is paused
                }

                console.error(error);
                return await response.send(event, context, response.FAILED);
            }
        };

        function executeStatement(sql, parameters) {
            parameters = Object.entries(parameters).map(([name, stringValue]) => ({name, value: {stringValue}}));
            return RDSDataService.executeStatement({resourceArn, secretArn, sql, parameters}).promise();
        }

Outputs:
  DatabaseUserServiceToken:
    Description: Lambda function that can be used to create a user on the database server in CloudFormation
    Value: !GetAtt DatabaseUserResourceLambda.Arn
    Export: {Name: !Sub '${AWS::StackName}-database-user-service-token'}
```

This is similar to the `DatabaseResourceLambda` from earlier. It even reuses the same IAMRole.

Let's get through it.

- Create: (where `event.PhysicalResourceId` is not defined) will create the user and then execute a `GRANT` per privilege.
- Update: will create a new user when the secret has changed and then execute a `GRANT` per privilege.
- Delete: Will simply drop the user if it exists.

### bring it together

So that is a lot of YAML so how can we use it all.

Let me show with more pseudo-yaml™.

```yaml

provider:
  # [...]
  environment:
    # the specifics differ depending on how you access the database
    DATABASE_RESOURCE: !GetAtt Database.Server
    DATABASE_SECRET: !Ref DatabaseUser
    DATABASE_NAME: !Ref Database

resources:
  Resources:
    Database: # [...]
    DatabaseUser: # [...]
```

And that's all you need in your service.
Now you can deploy as many stages or services as you want, using the same database server.

You now should idealy use the rds-data api to work with the database.
But that's not always an option,
so you can also define the VPC subnets as output in the shared stack and import them into your services.

But, If you can get some time, you should check if your database abstraction has an rds-data driver
or, if not, how hard it would be to create one. I [created one for php myself](https://github.com/Nemo64/dbal-rds-data)
because not having to use a VPC in my main application (and a costly a NAT Gateway) is awesome.
You don't even have to deal with how to receive the Secret and you get free connection pool management too. 

## Bonus: schedule the AutoPause feature

Aurora Serverless has an AutoPause feature which allows it to scale to 0 capacity when not used.
There is a massive downside though: it takes up to around a minute to wake up again.
This is unacceptable for production sites and very annoying during development as well,
but an unpaused Aurora Serverless costs ~$50 a month so it is worth investigating some alternatives.

What we can do is disabling AutoPause during work hours. Let's check:

1 capacity unit costs [$0,07 per hour](https://aws.amazon.com/rds/aurora/pricing/) (in the eu, 1 cent cheaper in US)
- 24 hours/day ~ 7 days/week = $50,40 / 30 days
- 12 hours/day ~ 7 days/week = $25,20 / 30 days
- 10 hours/day ~ 5 days/week = $15,00 / 30 days ~ average

You see, just running it for half a day is a lot cheaper
and limiting it even further will bring it in throwing distance to the smallest RDS instances possible
while still having the Multi-AZ failover and performance of an Aurora Database,
and possibly swallowing the price of a NAT Gateway if you can use the rds-data api instead of TCP connections.

Depending on what you are doing, it might even be fine for internal management tools that are only used during work hours.
However, usually that's not a good experience but cutting costs in half for development is still nice.

Remember, the database is still available when paused, it'll just take a minute to start
so it's not like you application will be inaccessable outside your work hours.

And also, it's Aurora Serverless. It can scale up automatically without you having to set up scaling rules. 

So how do we implement that? With a Lambda function in our shared CloudFormation template, of course.

```yaml
# serverless-shared.yml
Transform:
  - AWS::Serverless-2016-10-31 # for inline lambda function

Resources:
  DatabaseScalingSchedule:
    Type: AWS::Serverless::Function
    Properties:
      Description: !Sub 'Changes the Scaling Configuration of the database ${DatabaseServer}.'
      FunctionName: !Sub '${AWS::StackName}-database-scaling'
      Handler: index.handler
      Runtime: nodejs12.x
      MemorySize: 128 # mb, this function basically just waits for the api
      Role: !GetAtt DatabaseAccessPolicy.Arn
      Environment: {Variables: {SERVER: !Ref DatabaseServer}}
      Events:
        Worktime: {Type: Schedule, Properties: {Schedule: 'cron(0 7 ? * MON-FRI *)', Input: '{"AutoPause": false, "MinCapacity": 1, "MaxCapacity": 4}'}}
        Freetime: {Type: Schedule, Properties: {Schedule: 'cron(0 17 ? * MON-FRI *)', Input: '{"AutoPause": true, "MinCapacity": 1, "MaxCapacity": 2}'}}
      InlineCode: |-
        const RDS = new (require('aws-sdk/clients/rds'))({apiVersion: '2014-10-31'});
        exports.handler = async function (event) {
            return await RDS.modifyDBCluster({DBClusterIdentifier: process.env.SERVER, ScalingConfiguration: event}).promise();
        };
  DatabaseAccessPolicy:
    Type: AWS::IAM::Role
    Properties:
      RoleName: !Sub '${AWS::StackName}-${AWS::Region}-database-access-policy'
      AssumeRolePolicyDocument: {Version: '2012-10-17', Statement: [{Effect: Allow, Action: sts:AssumeRole, Principal: {Service: [lambda.amazonaws.com]}}]}
      Policies:
        - PolicyName: !Sub "${AWS::StackName}-database-access"
          PolicyDocument:
            Version: '2012-10-17'
            Statement:
              # [...]
              - {Effect: Allow, Action: rds:ModifyDBCluster, Resource: !Sub 'arn:${AWS::Partition}:rds:${AWS::Region}:${AWS::AccountId}:cluster:${DatabaseServer}'}
```

Quiet a lot shorter than the lambda functions from earlier, but this one does not require error handling.
I reuse the role from before, but I need to allow the ModifyDBCluster call.

I just basically pass the event object as `ScalingConfiguration` to `modifyDBCluster`.
Then I can just define scheduled events that pass my desired configuration at the desired times.

## Working example

I build a demo project that has shows a symfon/PHP project running with this database setup.

Even if you don't use PHP or Serverless, it might be worth a look to see or even try a working example.

See it here: [github.com/Nemo64/serverless-symfony](https://github.com/Nemo64/serverless-symfony)
