/* eslint-disable no-new */
const { Stack } = require('aws-cdk-lib');
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
const { KeyPair } = require('cdk-ec2-key-pair');
const fs = require('fs');


class DeployerStack extends Stack {
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

    // Configure Additional EC2 instances ===============================================================================
    const { deployerAttr } = options;
    const ec2Instances = [];
    const {
      hostPort = 0,
      connectTo,
      enable = false,
      deployInstance = false,
      properties = {},
    } = deployerAttr;
    // eslint-disable-next-line no-continue
    if (!enable) return;

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
  }
}

module.exports = { DeployerStack };
