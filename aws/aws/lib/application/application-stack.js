/* eslint-disable no-new */
const { Stack, Tags, CfnOutput, RemovalPolicy } = require('aws-cdk-lib');
const {
   Vpc,
   SecurityGroup,
   Peer,
   Port,
   Instance,
   InstanceType,
   MachineImage,
   OperatingSystemType,
   BlockDeviceVolume,
   UserData,
   SubnetType,
} = require('aws-cdk-lib').aws_ec2;
const {
  ApplicationLoadBalancer,
  ApplicationProtocol,
  ApplicationTargetGroup,
  ListenerAction,
  TargetType,
  ListenerCondition,
  IpTarget,
} = require('aws-cdk-lib').aws_elasticloadbalancingv2;
const { InstanceIdTarget } = require('aws-cdk-lib').aws_elasticloadbalancingv2_targets;
const { FileSystem, AccessPoint } = require('aws-cdk-lib').aws_efs;
const { RetentionDays, LogGroup } = require('aws-cdk-lib/aws-logs');
const ecs = require('aws-cdk-lib').aws_ecs;
const { Repository } = require('aws-cdk-lib').aws_ecr;
const iam = require('aws-cdk-lib').aws_iam;
const { Rule, Schedule, RuleTargetInput } = require('aws-cdk-lib').aws_events;
const { LambdaFunction } = require('aws-cdk-lib').aws_events_targets;
const { HostedZone, ARecord, RecordTarget } = require('aws-cdk-lib').aws_route53;
const { LoadBalancerTarget, CloudFrontTarget } = require('aws-cdk-lib').aws_route53_targets;
const { Certificate, CertificateValidation, DnsValidatedCertificate } =
  require('aws-cdk-lib').aws_certificatemanager;
const ssm = require('aws-cdk-lib').aws_ssm;
const cf = require('aws-cdk-lib').aws_cloudfront;
const s3 = require('aws-cdk-lib').aws_s3;
const { Metric } = require('aws-cdk-lib').aws_cloudwatch;
const { KeyPair } = require('cdk-ec2-key-pair');
const fs = require('fs');
const {updateEnvVars, findPriority, updateEcsCpus} = require('./utils.js');


class ApplicationStack extends Stack {
  /**
   * Creates Fargate Service using local definition to create an ECR image
   * or an image from DockerHub.
   * Attaches to the new Fargate service to our ALB.
   *
   * @param {cdk.Construct} scope
   * @param {string} id
   * @param {cdk.StackProps=} props
   */
  constructor(scope, id, props) {
    super(scope, id, props);

    const { options } = props;

    // VPC ==================================================================================================
    //  - Use preexisting VPC. Must have public (ALB) and private subnets (Fargate Taks)
    const { vpcAttr, envAttr } = options;

    // Use an existing VPC if specified in options, or the default VPC if not
    const { customVpcId, appSubnetIds } = vpcAttr;
    const vpc = Vpc.fromLookup(this, 'vpc', { vpcId: customVpcId });

    // Get public subnets from the VPC and confirm we have at least one
    const { publicSubnets } = vpc;
    if (!publicSubnets.length) {
      throw new Error('We need at least one public subnet in the VPC');
    }

    // Get application private subnets to deploy Apps
    const appSubnets = vpc.privateSubnets.filter(m => appSubnetIds.includes(m.subnetId));
    if (!appSubnets.length) {
      throw new Error('We need at least one application subnet in the VPC');
    }

    // DNS and Certificate =========================================================================================
    // - Create Certificate if necessary (one can be passed as parameter if it exists).
    // - Must have a domain registeres in Route53

    const { dnsAttr } = options;

    // Use custom domain and hostname for ALB. The Route53 Zone must be in the same account.
    const { zoneName = '', hostedZoneId = '', certificateArn = '' } = dnsAttr;
    const createCert = !certificateArn;
    if (!(zoneName && hostedZoneId)) {
      throw new Error('Route53 domain details are required');
    }

    // DNS Zone
    const zone = HostedZone.fromHostedZoneAttributes(this, 'zone', dnsAttr);

    // Use existing Certificate if supplied, or create new one. Existing Certificate must be in the same Account and Region.
    // Creating a certificate will try to create auth records in the Route53 DNS zone.
    const certificate = createCert
      ? new Certificate(this, 'cert', {
          domainName: `*.${zoneName}`,
          region: 'us-east-1',
          validation: CertificateValidation.fromDns(zone),
        })
      : Certificate.fromCertificateArn(this, 'cert', certificateArn);

    // US cerfitifate is used to deploy wallet in Cloud Formation, which requires a certificate from Virginia region (US-EAST-1)
    /*
    const certificateUs = createCert
      ? new DnsValidatedCertificate(this, 'certUs', {
          domainName: `*.${zoneName}`,
          hostedZone: zone,
          region: 'us-east-1',
        })
      : Certificate.fromCertificateArn(this, 'certUs', certificateArn);
    */
    const certificateUs = Certificate.fromCertificateArn(this, 'certUs', certificate.certificateArn);

    // ALB  =======================================================================================================
    const { albs = [] } = props;
    this.albs = albs;

    // ALB (external) =======================================================================================================
    // - Create ALB in public subnet
    // - Allow all HTTP and HTTPS inbound traffic
    // - Redirect all HHTP traffic to HTTPS
    // - Unknown traffic to HTTPS goes to 404

    // Security group for the ALB
    const albSg = new SecurityGroup(this, `AlbSg`, {
      description: `${envAttr.name} ALB Endpoint SG`,
      vpc,
      allowAllOutbound: true, // Rules to access the Fargate apps will be added by CDK
    });

    Tags.of(albSg).add('Name', `${envAttr.name}AlbSg`);

    // Ingress rules. Allow all HTTP and HTTPS public access
    albSg.addIngressRule(Peer.anyIpv4(), Port.tcp(443), 'allow public https access');
    albSg.addIngressRule(Peer.anyIpv4(), Port.tcp(80), 'allow public http access');

    // load balancer base
    const alb = new ApplicationLoadBalancer(this, `Alb`, {
      vpc,
      internetFacing: true,
      securityGroup: albSg,
    });

    // Https listener
    const httpsListener = alb.addListener('https', {
      port: 443,
      protocol: ApplicationProtocol.HTTPS,
      certificates: [certificate],
      open: false, // Prevent CDK from adding an allow all inbound rule to the security group
    });

    // addRedirect will create a HTTP listener and redirect to HTTPS
    alb.addRedirect({
      sourceProtocol: ApplicationProtocol.HTTP,
      sourcePort: 80,
      targetProtocol: ApplicationProtocol.HTTPS,
      targetPort: 443,
      open: false, // Prevent CDK from adding an allow all inbound rule to the security group
    });

    // Add default route to send a 404 response for unknown domains
    httpsListener.addAction('default', {
      action: ListenerAction.fixedResponse(404, {
        contentType: 'text/plain',
        messageBody: 'Nothing to see here',
      }),
    });

    this.albs.push({
      _alb: alb,
      _albSg: albSg,
      _httpsListener: httpsListener,
      _albType: 'external',
    });

    // ALB (internal) ======================================================================================================
    // - Create ALB in private subnet
    // - Allow all HTTP and HTTPS inbound traffic
    // - Redirect all HHTP traffic to HTTPS
    // - Unknown traffic to HTTPS goes to 404

    // Security group for the ALB
    const albInternalSg = new SecurityGroup(this, `AlbInternalSg`, {
      description: `${envAttr.name} ALB Internal Endpoint SG`,
      vpc,
      allowAllOutbound: true,
    });

    Tags.of(albInternalSg).add('Name', `${envAttr.name}AlbInternalSg`);

    // Ingress rules. Allow all HTTP and HTTPS public access
    albInternalSg.addIngressRule(Peer.anyIpv4(), Port.tcp(443), 'allow public https access');
    albInternalSg.addIngressRule(Peer.anyIpv4(), Port.tcp(80), 'allow public http access');

    // load balancer base
    const albInternal = new ApplicationLoadBalancer(this, `AlbInternal`, {
      vpc,
      internetFacing: false,
      securityGroup: albInternalSg,
    });

    // Https listener
    const httpsListenerInternal = albInternal.addListener('https', {
      port: 443,
      protocol: ApplicationProtocol.HTTPS,
      certificates: [certificate],
      open: false, // Prevent CDK from adding an allow all inbound rule to the security group
    });

    // addRedirect will create a HTTP listener and redirect to HTTPS
    albInternal.addRedirect({
      sourceProtocol: ApplicationProtocol.HTTP,
      sourcePort: 80,
      targetProtocol: ApplicationProtocol.HTTPS,
      targetPort: 443,
      open: false, // Prevent CDK from adding an allow all inbound rule to the security group
      vpcSubnets: {
        onePerAz: true,
      },
    });

    // Add default route to send a 404 response for unknown domains
    httpsListenerInternal.addAction('default', {
      action: ListenerAction.fixedResponse(404, {
        contentType: 'text/plain',
        messageBody: 'Nothing to see here',
      }),
    });

    this.albs.push({
      _alb: albInternal,
      _albSg: albInternalSg,
      _httpsListener: httpsListenerInternal,
      _albType: 'internal',
    });

    // EFS =====================================================================================
    const { efsAttr } = options;
    const { efsId, efsSgId } = efsAttr;

    const efs = FileSystem.fromFileSystemAttributes(this, `${envAttr.name}EFS`, {
      fileSystemId: efsId,
      securityGroup: SecurityGroup.fromSecurityGroupId(this, 'EfsSg', efsSgId, {
        allowAllOutbound: false,
      }),
    });

    // ECS Cluster =============================================================================

    const { clusterName = '' } = props;
    const cluster = new ecs.Cluster(this, `Cluster${clusterName}`, {
      vpc,
      containerInsights: true,
    });

    // Fargate Tasks ===========================================================================

    // Task Role
    if (!props.taskRole) {
      const taskRole = new iam.Role(this, 'ecsTaskExecutionRole', {
        assumedBy: new iam.ServicePrincipal('ecs-tasks.amazonaws.com'),
      });

      taskRole.addToPrincipalPolicy(
        new iam.PolicyStatement({
          actions: [
            'ssmmessages:CreateControlChannel',
            'ssmmessages:CreateDataChannel',
            'ssmmessages:OpenControlChannel',
            'ssmmessages:OpenDataChannel',
            'dynamodb:Scan',
            'dynamodb:Query',
            'dynamodb:PutItem',
            'dynamodb:DeleteItem',
            'cloudwatch:PutMetricData',
            'apigateway:*',
            'execute-api:Invoke',
            'execute-api:ManageConnections',
          ],
          resources: ['*'],
        }),
      );

      taskRole.addManagedPolicy(
        iam.ManagedPolicy.fromAwsManagedPolicyName('service-role/AmazonECSTaskExecutionRolePolicy'),
      );
      this.taskRole = taskRole;
    } else {
      this.taskRole = props.taskRole;
    }

    // ===== Tasks Definition
    const { appsAttr } = options;

    const taskDefinition = [];
    const logGroup = [];
    const logDriver = [];
    const appSg = [];
    const tg = [];
    this.services = [];
    const mgtTarget = [];
    const startRule = [];
    const stopRule = [];
    const efsAccessPoint = [];

    let priority = 0
    const listenerPriority =
    process.env.TASK_PRIORITIES === ''
      ? {}
      : JSON.parse(process.env.TASK_PRIORITIES.replaceAll('\\', '"'), 'utf8');

    const _clusterName = clusterName === '' ? '' : `${clusterName.toUpperCase()}_`;

    for (const appAttr of appsAttr) {
      // Fargate Task
      const { name, cpu = 1, assignPublicIp = false, enable = true, nInstances = 1, desiredCount = 1, } = appAttr(_clusterName);
      // Skip task if disabled
      if (!enable) {
        // eslint-disable-next-line no-continue
        continue;
      }
      let instanceLabel="";
      for (let instanceIndex=0; instanceIndex < nInstances; instanceIndex++) {
        if (instanceIndex) {
          instanceLabel = (instanceIndex+1).toString();
        }

        const vcpus = updateEcsCpus(cpu);
        taskDefinition.push(
          new ecs.FargateTaskDefinition(this, `${envAttr.name}-${name}${instanceLabel}taskDef`, {
            memoryLimitMiB: vcpus * 2,
            cpu : vcpus,
            taskRole: this.taskRole,
          }),
        );
  
        // Logs
        logGroup.push(
          new LogGroup(this, `${envAttr.name}-${name}${instanceLabel}logGroup`, {
            logGroupName: `/ecs/${envAttr.name}-${name}${instanceLabel}App`,
            removalPolicy: RemovalPolicy.DESTROY,
            retention: RetentionDays.ONE_WEEK,
          }),
        );
  
        logDriver.push(
          new ecs.AwsLogDriver({
            logGroup: logGroup[logGroup.length - 1],
            streamPrefix: `${envAttr.name}-${name}${instanceLabel}Logs`,
          }),
        );
  
        // ECR Repo
        const { containerInfo } = appAttr(_clusterName);
        const { imageName, imageTag, imageNameIndex = '' } = containerInfo;
        let _imageName = imageName;
        if (imageNameIndex.includes(',')) {
          const imageIndex = Number(imageNameIndex.split(',')[instanceIndex]);
          _imageName = imageName[imageIndex];
        } else if (imageNameIndex !== '') {
          _imageName = imageName[Number(imageNameIndex)];
        }
        const repository = Repository.fromRepositoryName(
          this,
          `${envAttr.name}-${name}${instanceLabel}Repo`,
          _imageName,
        );
  
        // Application Security Group
        // Note this SG will only allow traffic from the ALB.
        appSg.push(
          new SecurityGroup(this, `${envAttr.name}-${name}${instanceLabel}Sg`, {
            vpc,
            description: `${envAttr.name}-${name}${instanceLabel} SG`,
            securityGroupName: `${envAttr.name}-${name}${instanceLabel}Sg`,
            allowAllOutbound: true, // Allow all so we can get Docker Hub images
          }),
        );
        Tags.of(appSg[appSg.length - 1]).add('Name', `${envAttr.name}-${name}${instanceLabel}Sg`);
  
        const { portInfo = [], environmentVars, secretEnvVars = {}, secretVars = [], command } = containerInfo;
        const portMappings = [];
        const tgInfo = [];
  
        // - Generate portMapings (container Port - hostPort - potocol)
        // - Add ingress rules to Application SG (only allow traffic from ALB:hostPort
        // - Add additional ingress rules (maybe for ssh..)
        // - Generate DNS alias for each portMapping described in the Application
        // - Generate target group for each portMapping pointing to hostPort
        // - Add an action to Alb to point each DNS to the corresponding TG
        const updatedEnvVars = updateEnvVars(environmentVars, instanceIndex);
        for (const port of portInfo) {
          const {
            ingressRulesSg = [],
            httpHeader = [],
            containerPort = 80,
            hostPort = 80,
            hostname,
            protocol = ecs.Protocol.TCP,
            healthcheck = {},
            albType = 'external',
          } = port;
          const indexedHostname = `${hostname}${instanceLabel}`
          const { _alb, _albSg, _httpsListener } =
            albType === 'external' ? this.albs[0] : this.albs[1];
          // Add Alb -> application to app security group -
          appSg[appSg.length - 1].addIngressRule(
            _albSg,
            Port.tcp(hostPort),
            'Application Load Balancer',
          );
  
          // Aditional Ingress rules
          // If you need to SSH to the container you will need to add additional ingress rules here.
          for (const rule of ingressRulesSg) {
            appSg[appSg.length - 1].addIngressRule(
              Peer.ipv4(rule.cidr),
              Port.tcp(rule.port),
              rule.description,
            );
          }
 
          // update port numbers if necessary
          portMappings.push({
            //containerPort: instanceIndex=== 0 ? containerPort : containerPort + instanceIndex + 1,
            //hostPort: instanceIndex === 0 ? hostPort : hostPort + instanceIndex + 1,
            containerPort,
            hostPort,
            protocol,
          });
  
          // Add DNS alias for the app
          const fqdn = `${indexedHostname}.${zoneName}`;
  
          new ARecord(this, `${envAttr.name}-${indexedHostname}Alias`, {
            recordName: fqdn,
            zone,
            comment: `DNS Alias for ${indexedHostname}`,
            target: RecordTarget.fromAlias(new LoadBalancerTarget(_alb)),
          });
  
          tg.push(
            new ApplicationTargetGroup(this, `${envAttr.name}-${indexedHostname}TG`, {
              vpc,
              port: hostPort,
              protocol: ApplicationProtocol.HTTP,
              // IP target type is required for Fargate services - it must be specified here if attaching services in other stacks
              targetType: TargetType.IP,
            }),
          );
  
          // Add health checks with additional information
          tg[tg.length - 1].configureHealthCheck(healthcheck);
  
          priority = findPriority(listenerPriority, indexedHostname);
          // Add route to the target group
          if (httpHeader.length > 0 && httpHeader[0]) {
            _httpsListener.addAction(`${envAttr.name}-${indexedHostname}-Action`, {
              action: ListenerAction.forward([tg[tg.length - 1]]),
              conditions: [
                ListenerCondition.hostHeaders([fqdn]),
                ListenerCondition.httpHeader(httpHeader[1],[httpHeader[2]])
              ],
              priority,
            });
          } else {
            _httpsListener.addAction(`${envAttr.name}-${indexedHostname}-Action`, {
              action: ListenerAction.forward([tg[tg.length - 1]]),
              conditions: [ListenerCondition.hostHeaders([fqdn])],
              priority,
            });
          }
          listenerPriority[indexedHostname] = priority;
   
          tgInfo.push({ tg: tg[tg.length - 1], url: `https://${fqdn}/`, indexedHostname });
        }
  
        const { efsVolumes = [] } = appAttr(_clusterName);
  
        for (const volumeInfo of efsVolumes) {
          efsAccessPoint.push(
            new AccessPoint(this, `${envAttr.name}-${name}${instanceLabel}EfsAP`, {
              fileSystem: efs,
              path: volumeInfo.path,
            }),
          );
  
          taskDefinition[taskDefinition.length - 1].addVolume({
            name: volumeInfo.volumeName,
            efsVolumeConfiguration: {
              fileSystemId: efs.fileSystemId,
              transitEncryption: 'ENABLED',
              authorizationConfig: {
                accessPointId: efsAccessPoint[efsAccessPoint.length - 1].accessPointId,
                iam: 'ENABLED',
              },
            },
          });
        }
  
        const secrets = {};
        for (const secret of secretVars) {
          let _secret;
          let secretIndex = instanceIndex;
          // There are some secrets, such as mongodb params, that only require
          // first index
          if (secret.parameterName.length == 1) {
            secretIndex = 0;
          }
          if (secret.type[0] === 'string') {
            _secret = ssm.StringParameter.fromStringParameterAttributes(
              this,
              `${envAttr.name}-${name}${instanceLabel}-${secret.parameterName[secretIndex]}`,
              {
                parameterName: `/${envAttr.name}/${secret.parameterName[secretIndex]}`,
              },
            );
            secretEnvVars[`${secret.envName[0]}`] = _secret.stringValue;
          } else {
            _secret = ssm.StringParameter.fromSecureStringParameterAttributes(
              this,
              `${envAttr.name}-${name}${instanceLabel}-${secret.parameterName[secretIndex]}`,
              {
                parameterName: `/${envAttr.name}/${secret.parameterName[secretIndex]}`,
                version: 1,
              },
            );
            secrets[`${secret.envName[0]}`] = ecs.Secret.fromSsmParameter(_secret);
          }
          _secret.grantRead(this.taskRole);
        }

        // Container
        const container = taskDefinition[taskDefinition.length - 1].addContainer(
          `${envAttr.name}-${name}${instanceLabel}Container`,
          {
            image: ecs.ContainerImage.fromEcrRepository(repository, imageTag),
            containerName: `${envAttr.name}-${name}${instanceLabel}Container`,
            logging: logDriver[logDriver.length - 1],
            environment: { ...updatedEnvVars, ...secretEnvVars },
            secrets,
            command,
            portMappings,
          },
        );
  
        for (const volumeInfo of efsVolumes) {
          container.addMountPoints({
            containerPath: volumeInfo.containerPath,
            sourceVolume: volumeInfo.volumeName,
            readOnly: false,
          });
        }
        if (efsVolumes.length) {
          taskDefinition[taskDefinition.length - 1].addToTaskRolePolicy(
            new iam.PolicyStatement({
              actions: [
                'elasticfilesystem:ClientRootAccess',
                'elasticfilesystem:ClientWrite',
                'elasticfilesystem:ClientRead',
                'elasticfilesystem:ClientMount',
                'elasticfilesystem:DescribeMountTargets',
              ],
              resources: [
                `arn:aws:elasticfilesystem:${envAttr.region}:${envAttr.account}:file-system/${efs.fileSystemId}`,
              ],
            }),
          );
        }
  
        // Service
        this.services.push(
          new ecs.FargateService(this, `${envAttr.name}-${name}${instanceLabel}Svc`, {
            cluster,
            taskDefinition: taskDefinition[taskDefinition.length - 1],
            // Public IP required so we can get the ECR or Docker image. If you have a NAT Gateway or ECR VPC Endpoints set this to false.
            assignPublicIp,
            desiredCount,
            // TODO: for some reason, all private subnets are selected.
            vpcSubnets: appSubnets,
            securityGroups: [appSg[appSg.length - 1]],
            maxHealthyPercent: 100,
          }),
        );
  
        // enable EnableExecuteCommand for the service
        this.services[this.services.length - 1].node
          .findChild('Service')
          .addPropertyOverride('EnableExecuteCommand', true);
  
        new CfnOutput(this, `${envAttr.name}-${name}${instanceLabel}EcsExecCommand`, {
          value: `ecs_exec_service ${cluster.clusterName} ${
            this.services[this.services.length - 1].serviceName
          } ${taskDefinition[taskDefinition.length - 1].defaultContainer?.containerName}`,
        });
        let tgIdx = 0;
        for (const tgEl of tgInfo) {
          // tgEl.tg.addTarget(this.services[this.services.length - 1]);
          tgEl.tg.addTarget(
            this.services[this.services.length - 1].loadBalancerTarget({
              containerPort: portMappings[tgIdx].containerPort,
              containerName: `${envAttr.name}-${name}${instanceLabel}Container`,
            }),
          );
          tgIdx++;
          // Export the app URL
          new CfnOutput(this, `${tgEl.indexedHostname}CustomUrl`, {
            description: `${tgEl.indexedHostname} Url`,
            value: tgEl.url,
          });
        }
  
        // Add Schedule =====================================================================================================
        const { ecsScheduleFnc } = props;
        const { downtime = '' } = appAttr(_clusterName).schedule;
        let start = '';
        let stop = '';
        if (downtime) {
           const { at = '', length = '10'} = downtime;
           if (at === 'random') {
             const stopMin = Math.floor(Math.random() * 60)
             stop = `${stopMin} * * * ? *`;
             start =`${(stopMin + Number(length)) % 60} * * * ? *`;
           }
        } 
        if (start || stop) {
          // Lambda target config
          const params = {
            clusterArn: cluster.clusterArn,
            serviceName: this.services[this.services.length - 1].serviceName,
          };
  
          // Schedule Rules
          if (start) {
            params.active = true;
            mgtTarget.push(
              new LambdaFunction(ecsScheduleFnc, {
                event: RuleTargetInput.fromObject({ params }),
                retryAttempts: 3,
              }),
            );
            startRule.push(
              new Rule(this, `${envAttr.name}-${name}${instanceLabel}-startRule`, {
                description: 'Start ECS Task',
                schedule: Schedule.expression(`cron(${start})`),
              }),
            );
            startRule[startRule.length - 1].addTarget(mgtTarget[mgtTarget.length - 1]);
          }
          if (stop) {
            params.active = false;
            mgtTarget.push(
              new LambdaFunction(ecsScheduleFnc, {
                event: RuleTargetInput.fromObject({ params }),
                retryAttempts: 3,
              }),
            );
            stopRule.push(
              new Rule(this, `${envAttr.name}-${name}${instanceLabel}-stopRule`, {
                description: 'Stop ECS Task',
                schedule: Schedule.expression(`cron(${stop})`),
              }),
            );
            stopRule[stopRule.length - 1].addTarget(mgtTarget[mgtTarget.length - 1]);
          }
        }
      }
    }

    // Configure Additional EC2 instances ===============================================================================
    const { ec2InstancesAttr } = options;
    const ec2Instances = [];
    for (const ec2Attr of ec2InstancesAttr) {
      const {
        ip = '',
        hostname,
        hostPort = 0,
        healthcheck = {},
        connectTo,
        s3BucketArn,
        enable = false,
        deployInstance = false,
        properties = {},
      } = ec2Attr;
      const { _alb, _httpsListener } = connectTo === 'external' ? this.albs[0] : this.albs[1];
      // eslint-disable-next-line no-continue
      if (!enable || _clusterName != '') continue;

      // Add DNS alias for the app
      const fqdn = `${hostname}.${zoneName}`;

      if (connectTo === 'route-53') {
        const viewerCert = cf.ViewerCertificate.fromAcmCertificate(
          {
            certificateArn: certificateUs.certificateArn,
            node: this.node,
            stack: this,
            // eslint-disable-next-line no-loop-func
            metricDaysToExpiry: () =>
              new Metric({
                namespace: 'TLS viewer certificate validity',
                metricName: 'TLS Viewer Certificate expired',
              }),
          },
          {
            sslMethod: cf.SSLMethod.SNI,
            securityPolicy: cf.SecurityPolicyProtocol.TLS_V1_2_2021,
            // aliases: [`*.${zoneName}`],
            aliases: [fqdn],
          },
        );

        const cloudFrontOAI = new cf.OriginAccessIdentity(this, 'OAI', {
          comment: `OAI website.`,
        });

        const customError403Property = {
          errorCode: 403,

          // the properties below are optional
          errorCachingMinTtl: 10,
          responseCode: 200,
          responsePagePath: '/',
        };
        const customError404Property = {
          errorCode: 404,

          // the properties below are optional
          errorCachingMinTtl: 10,
          responseCode: 200,
          responsePagePath: '/',
        };

        const distribution = new cf.CloudFrontWebDistribution(this, `${hostname}-CFDistribution`, {
          viewerCertificate: viewerCert,
          originConfigs: [
            {
              s3OriginSource: {
                s3BucketSource: s3.Bucket.fromBucketArn(this, `${hostname}-bucketn`, s3BucketArn),
                originAccessIdentity: cloudFrontOAI,
              },
              behaviors: [{ isDefaultBehavior: true }],
            },
          ],
          errorConfigurations: [customError403Property, customError404Property],
          priceClass: cf.PriceClass.PRICE_CLASS_ALL,
        });

        new ARecord(this, `${hostname}Alias`, {
          recordName: fqdn,
          zone,
          comment: `DNS Alias for ${hostname}`,
          target: RecordTarget.fromAlias(new CloudFrontTarget(distribution)),
        });

        // eslint-disable-next-line no-continue
        continue;
      }

      if (deployInstance) {
        // Create Security Group and ingress rules
        const ec2Sg = new SecurityGroup(this, 'ec2Sg', {
          description: `${envAttr.name}-${properties.name}-sg`,
          vpc,
          allowAllOutbound: true, // Rules to access the Fargate apps will be added by CDK
        });

        const ec2InstanceCidr = connectTo === 'internal' ? '10.48.0.0/16' : '0.0.0.0/0';

        ec2Sg.addIngressRule(Peer.ipv4(ec2InstanceCidr), Port.tcp(80), 'allow http access');
        ec2Sg.addIngressRule(Peer.ipv4(ec2InstanceCidr), Port.tcp(443), 'allow https access');
        ec2Sg.addIngressRule(Peer.ipv4(ec2InstanceCidr), Port.tcp(hostPort), 'allow https access');
        for (const sgPort of properties.sgPorts) {
          ec2Sg.addIngressRule(Peer.ipv4(ec2InstanceCidr), Port.tcp(sgPort), 'allow https access');
        }

        // Create key pair
        const keyPair = new KeyPair(this, 'EC2SSHKeyPair', {
          name: `${envAttr.name}-${properties.name}-key`,
        });

        // Create EC2 instance
        // Add user data to initialize EC2 instance to edge node
        const userDataScript = fs.readFileSync(`./scripts/${properties.userDataScript}`, 'utf8');
        // 👇 add the User Data script to the Instance
        //instance.addUserData(userDataScript);
        const instance = new Instance(this, `EC2Instance-${properties.name}`, {
          vpc,
          instanceType: new InstanceType(properties.instanceType),
          // Latest stable Ubuntu
          machineImage: MachineImage.fromSSMParameter(properties.instanceImage, OperatingSystemType.LINUX),
          keyName: keyPair.keyPairName, // Keypair automatically gets added to EC2 ssh keys
          securityGroup: ec2Sg,
          blockDevices: [
            {
              deviceName : "/dev/sda1",
              volume : BlockDeviceVolume.ebs(properties.volumeSize)
            }
          ],
          userData: UserData.custom(userDataScript),
          vpcSubnets: {
            subnetType: connectTo === 'external' ? SubnetType.PUBLIC : SubnetType.PRIVATE_WITH_NAT,
          },
        });


        ec2Instances.push(instance)

      }
      new ARecord(this, `${hostname}Alias`, {
        recordName: fqdn,
        zone,
        comment: `DNS Alias for ${hostname}`,
        target: RecordTarget.fromAlias(new LoadBalancerTarget(_alb)),
      });

      const ec2TargetType = properties.targetType === 'instance' ? TargetType.INSTANCE : TargetType.IP;
      const ec2Targets = properties.targetType === 'instance' ? new InstanceIdTarget(ec2Instances[ec2Instances.length - 1].instanceId, hostPort) : new IpTarget(ip);
      tg.push(
        new ApplicationTargetGroup(this, `${hostname}TG`, {
          vpc,
          port: hostPort,
          protocol: ApplicationProtocol.HTTP,
          // IP target type is required for Fargate services - it must be specified here if attaching services in other stacks
          targetType: ec2TargetType,
          targets: [ec2Targets],
        }),
      );

      // Add health checks with additional information
      tg[tg.length - 1].configureHealthCheck(healthcheck);

      priority = findPriority(listenerPriority, hostname);
      // Add route to the target group
      _httpsListener.addAction(`${hostname}-Action`, {
        action: ListenerAction.forward([tg[tg.length - 1]]),
        conditions: [ListenerCondition.hostHeaders([fqdn])],
        priority,
      });
      listenerPriority[hostname] = priority;
    }


    // If we are just checking diffs, no need to save priority file
    if (process.env.SAVE_TASK_PRIORITY) {
       fs.writeFileSync(`/tmp/nightfall.priority`, JSON.stringify(listenerPriority));
    }
  }
}
module.exports = { ApplicationStack };
