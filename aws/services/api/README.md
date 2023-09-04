# API
Nightfall API service processes requests to deploy different nightfall environments.

## Launch
```
npm install
npm start
```
API is launched in port 9000

## Documentation
In a browser, go to http://localhost:9000/api-docs 

## Howto
1. Build Nightfall environment: `POST /environment`

A Nightfall environment is made up by the following infrastructure. 
- VPC with CIDR blocks 10.48.0.0/16
- 1 Internet GW 
- 3 Public Subnets (10.48.1.0/24, 10.48.2.0/24 and 10.48.3.0/24)
- 3 Private Subnets (10.48.21.0/24, 10.48.22.0/24 and 10.48.23.0/24)
- 4 routing tables (1 public with all public subnets, and one for each private subnet)
- 1 NAT in each public subnet, and associate it to one private subnet
- 1 EFS file system
- 1 documentDb cluster
- 1 VPN client endpoint with certificate in `./certificates/nightfall-<ENV_NAME>.ovpn`
- 2 S3 bucket
- 1 env file configuring the environment in `./env/<ENV_NAME>.env`
- 1 cdk file in `./aws/contexts/cdk.context.<ENV_NAME>.json`
- 4 lambda functions and 1 API Gateway
- fill AWS parameter store
- if WALLET_ENABLE is set to true, a cloudfront distribution will be created where browser wallet can be deployed

Environment is build by sending a `POST /environment` with the environment name and region where environment is to be created.

2. Query status: `GET /environment` or `GET /environment/{envName}`
There are several options to query the status of a given environment. Nightfall API service stores the status of the different
created environments in memory. However, its possible that if the service is restarted, the information is lost. Upon service 
startup, the status is automatically refreshed to keep an updated copy.

To check status, there are two mechanisms:
- Query status for all environments: `GET /environment`
- Query status for a given envitonment: `GET /environment/{envName}`

Status provides an overview of the different available environments and their status. Status includes the following information :
- action: Last action recorded on given environment
- status: Status of last action (`pending`, `success`, `failed`)
- region: AWS region where environment has been built
- clusters: Auxiliary clusters, typically used by additional client servers created

Any other command sent while an environment is being created will return a 423 status, meaning that the system is busy.

3. Deploy Nightfall Infrastructure: `POST /deployment`
Once the environment has been successfully created, it is time to deploy the minimum infrastructure for the first client to be able to send transactions. Infrastructure deployment is done with `POST /deployment` passing the environmentName as parameters. This request builds and pushes containers, deploys services and smart contracts, and funds Eth accounts.

Status can be retrieved with either `GET /environment` or `GET /environment/{envName}`

4. Deploy Nightfall Cluster: `POST /deployment/cluster`
A Cluster is requires whenever a second client is requires. A cluster is formed by a client and a regulator service. A cluster can be deployed with `POST /deployment/cluster` and passing the environment and cluster name. Note that the 
environment needs to exist, and the cluster name cannot be repeated.

Status can be retrieved with either `GET /environment` or `GET /environment/{envName}`

5. Get Services URLs: `POST /deployment/urls/{envName}` followed by `GET /environment/{envName}`
To retrieve the URLS where different Nightfall services can be accessed in a given environment can be done with the
combination of two requests. First, one needs to send a `POST /deployment/urls/{envName}` to update the URLs from a given
environment name. The URLs can be then retreived using `GET /environment/{envName}`

6. Delete Clusters: `DELETE /deployment/cluster/{envName}`
Clusters can be deleted with `DELETE /deployment/cluster/{envName}` command.

7. Delete Deployment: `DELETE /deployment/{envName}`
When all clusters are deleted, main infrastructure can be destroyed with `DELETE /deployment/{envName}`

8. Delete Environment: `DELETE /environment`
Once all Nightfall infrastrucure has been destroyed, one can delete the additional AWS resources with `DELETE /environment/{envName}`

