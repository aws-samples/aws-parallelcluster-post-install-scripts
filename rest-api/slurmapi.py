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
submit_job_parser.add_argument('-j', '--job', type=str, required=True)

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
    with open(args.job) as job_file:
        job_json = json.load(job_file)
    r = requests.post(f'{url}/job/submit', headers=headers, json=job_json, verify=False)
if args.command == 'list-jobs':
    r = requests.get(f'{url}/jobs', headers=headers, verify=False)
if args.command == 'describe-job':
    r = requests.get(f'{url}/job/{args.job_id}', headers=headers, verify=False)
if args.command == 'cancel-job':
    r = requests.delete(f'{url}/job/{args.job_id}', headers=headers, verify=False)

print(r.text)
