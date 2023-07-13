# Call the API

## Using curl

To do this, we’ll need a few pieces of information. Alternatively, we can use the [Python requests library](#using-the-python-requests-library) to along with boto3 to get this information programatically and call the API.

- JWT token: If you configured your cluster correctly, the post install script should have create a secret in your AWS SecretsManager under the name `slurm_token_$CLUSTER_NAME`. Either use the AWS console or the AWS CLI to find your secret based on the cluster name:

```bash
aws secretsmanager get-secret-value --secret-id slurm_token_$CLUSTER_NAME | grep SecretString
```
>**NOTE:** Since the Slurm REST API script is not integrated into ParallelCluster, this secret will not be automatically deleted along with the cluster. You may want to remove it manually on cluster deletion.

- Head node public IP: This can be found in your EC2 dashboard or by using the ParallelCluster CLI:

```bash
pcluster describe-cluster-instances -n $CLUSTER_NAME | grep "publicIp\|nodeType\|{\|}"
```

- Cluster user: This depends on your AMI, but it will usually be either `ec2-user`, `ubuntu`, or `centos`.

Now we can call the API using curl:

```bash
curl -H "X-SLURM-USER-NAME: $CLUSTER_USER" -H "X-SLURM-USER-TOKEN: $JWT" https://$IP/slurm/v0.0.39/ping -k
```

You’ll get a response back like:

```json
{
    "meta": {
        "plugin": {
        "type": "openapi\/v0.0.39",
        "name": "REST v0.0.39"
        },
    "Slurm": {
      "version": {
        "major": 23,
        "micro": 2,
        "minor": 2
      }...
```

To submit a job using the API, let’s specify the job parameters using JSON.
>**NOTE:** You may need to modify the standard directories depending on the cluster user

```json
{
    "job": {
        "name": "test",
        "current_working_directory": "/home/ec2-user",
        "environment": [
            "/bin:/user/bin/:/user/local/bin/",
            "/lib/:/lib64/:/usr/local/lib"]
    },
    "script": "#!/bin/bash\nsleep 60\necho 'REST API OUTPUT'"
}
```

Now we can post our job to the API:

```bash
curl -H "X-SLURM-USER-TOKEN: $CLUSTER_USER" -H "X-SLURM-USER-TOKEN: $JWT" -X POST https://$IP/slurm/v0.0.39/job/submit -H "Content-Type: application/json" -d @testjob.json -k
```

Now let’s verify that the job is running:

```bash
curl -H "X-SLURM-USER-NAME: $CLUSTER_USER" -H "X-SLURM-USER-TOKEN: $JWT" https://$IP/slurm/v0.0.39/jobs -k
```

## Using the Python [requests](https://requests.readthedocs.io/en/latest/) library
Create a script called `slurmapi.py` with the following contents:

```python
#!/usr/bin/env python3
import argparse
import boto3
import requests
import json

# Create argument parser
parser = argparse.ArgumentParser()
parser.add_argument('-n', '--cluster-name', type=str, required=True)
parser.add_argument('-u', '--cluster-user', type=str, required=False)
subparsers = parser.add_subparsers(dest='command', required=True)

diag_parser = subparsers.add_parser('diag', help="Get diagnostics")
ping_parser = subparsers.add_parser('ping', help="Ping test")

submit_job_parser = subparsers.add_parser('submit-job', help="Submit a job")
submit_job_parser.add_argument('-j', '--job-path', type=str, required=True)

list_jobs_parser = subparsers.add_parser('list-jobs', help="List active jobs")

describe_job_parser = subparsers.add_parser('describe-job', help="Describe a job by id")
describe_job_parser.add_argument('-j', '--job-id', type=int, required=True)

cancel_parser = subparsers.add_parser('cancel-job', help="Cancel a job")
cancel_parser.add_argument('-j', '--job-id', type=int, required=True)

args = parser.parse_args()

# Get JWT token
client = boto3.client('secretsmanager')
boto_response = client.get_secret_value(SecretId=f'slurm_token_{args.cluster_name}')
jwt_token = boto_response['SecretString']

# Get cluster headnode IP
client = boto3.client('ec2')
filters = [{'Name': 'tag:parallelcluster:cluster-name', 'Values': [args.cluster_name]}]
boto_response = client.describe_instances(Filters=filters)
headnode_ip = boto_response['Reservations'][0]['Instances'][0]['PublicIpAddress']

url = f'https://{headnode_ip}/slurm/v0.0.39'
headers = {'X-SLURM-USER-TOKEN': jwt_token}
if args.cluster_user:
    headers['X-SLURM-USER-NAME'] = args.cluster_user

# Make request
if args.command == 'ping':
    r = requests.get(f'{url}/ping', headers=headers, verify=False)
if args.command == 'diag':
    r = requests.get(f'{url}/diag', headers=headers, verify=False)
if args.command == 'submit-job':
    with open(args.job_path) as job_file:
        job_json = json.load(job_file)
    r = requests.post(f'{url}/job/submit', headers=headers, json=job_json, verify=False)
if args.command == 'list-jobs':
    r = requests.get(f'{url}/jobs', headers=headers, verify=False)
if args.command == 'describe-job':
    r = requests.get(f'{url}/job/{args.job_id}', headers=headers, verify=False)
if args.command == 'cancel-job':
    r = requests.delete(f'{url}/job/{args.job_id}', headers=headers, verify=False)

print(r.text)
```

To grant execute permissions to the script, run:

```bash
chmod +x slurmapi.py
```

Now you can invoke API calls such as `ping` like so:

```bash
./slurmapi.py -n [cluster_name] ping
```

For more commands, run:

```bash 
./slurmapi.py -h
```

Feel free to modify this script as you see fit. Find more endpoints using the [Slurm REST API reference](https://slurm.schedmd.com/rest_api.html).
