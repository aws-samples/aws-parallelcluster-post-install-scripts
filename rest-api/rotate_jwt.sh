jwt_token=$(/opt/slurm/bin/scontrol token lifespan=$3 | awk -F'=' '{print $2}')
/bin/aws secretsmanager update-secret --secret-id $1 --region $2 --secret-string $jwt_token
