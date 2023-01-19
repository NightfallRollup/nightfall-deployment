const { Stack } = require('aws-cdk-lib');
const { CfnWebACLAssociation, CfnWebACL } = require('aws-cdk-lib').aws_wafv2;


class WAFStack extends Stack {
   /**
   * Creates a WAF and connects it to public ALB
   *
   * @param {cdk.Construct} scope
   * @param {string} id
   * @param {cdk.StackProps=} props
   */
  constructor(scope, id, props) {
    super(scope, id, props);
    const { options, alb } = props;
    const { envAttr, wafAttr } = options;

    const waf = new WAF(this, `${envAttr}-WAFv2`, {envAttr, wafAttr});
    // Create an association with the dev alb
    new WebACLAssociation(this, `${envAttr}-ACL+`,{
        resourceArn: alb.loadBalancerArn,
        webAclArn: waf.attrArn,
    });
  }
}



class WAF extends CfnWebACL {
    constructor(scope, id, props) {
        const { envAttr, wafAttr } = props;
        super(scope, id,{
            defaultAction: { allow: {} },
            visibilityConfig: {
                cloudWatchMetricsEnabled: true,
                metricName: `${envAttr.name}-metric`,
                sampledRequestsEnabled: false,
              },
            scope: 'REGIONAL',
            name: `${envAttr.name}-waf`,
            rules: wafAttr.map(wafRule => {
                if (wafRule.enable) { return wafRule.rule}})
        });
    }
}

class WebACLAssociation extends CfnWebACLAssociation {
    constructor(scope, id, props) {
        super(scope, id,{
            resourceArn: props.resourceArn,
            webAclArn: props.webAclArn,
        });
    }
}
module.exports = { WAFStack };