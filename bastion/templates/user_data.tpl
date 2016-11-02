#!/bin/bash

# Wait for IGW so we can get to all our network resources
until $(curl --output /dev/null --silent --head --fail https://aws.amazon.com); do
    echo -n "." && sleep 2
done

hostname bastion
yum -y update
yum -y install awslogs curl jq yum-cron
pip install awscli --upgrade

# Sync SSH host keys
INSTANCE_ID=$(curl --silent http://169.254.169.254/latest/meta-data/instance-id)
keys_not_present() {
    return $(aws s3 ls s3://${s3_bucket}/${s3_bucket_prefix}/ssh/ssh_host_rsa_key --region ${region} | wc -l)
}
download_keys() {
    rm -f /etc/ssh/ssh_host*
    aws s3api wait object-exists --bucket ${s3_bucket} --key ${s3_bucket_prefix}/ssh/ssh_host_rsa_key --region ${region}
    aws s3 sync s3://${s3_bucket}/${s3_bucket_prefix}/ssh/ /etc/ssh/ --region ${region} --include 'ssh_host*'
    find /etc/ssh -name "*key" -exec chmod 600 {} \;
    service sshd restart
}

# Possible States:
# - Shared keys present, download and replace
# - Shared keys absent
#   - If lead server (alphabetically first instance ID) upload your host keys
#   - If not lead, poll for presence of keys (up to 5 minutes) download and replace when available
if keys_not_present ; then
    LEAD_BASTION=$(aws autoscaling describe-auto-scaling-instances --region ${region} | jq --raw-output --sort-keys '.AutoScalingInstances[].InstanceId' | head -1)
    if [ "$INSTANCE_ID" = "$LEAD_BASTION" ] ; then
        aws s3 cp /etc/ssh/ s3://${s3_bucket}/${s3_bucket_prefix}/ssh/ --recursive --exclude '*' --include '*key*' --region ${region}
    else
        download_keys
    fi
else
    download_keys
fi


# Configure Logging

echo "* * * * * aws cloudwatch put-metric-data --region ${region} --metric-name ssh-sessions --namespace "bastion" --timestamp \$(date -Ih) --value \$(w -h | wc -l)" >> /var/spool/cron/root

echo "[general]
state_file = /var/lib/awslogs/agent-state
[/var/log/messages]
datetime_format = %b %d %H:%M:%S
file = /var/log/messages
log_stream_name = {instance_id}/var/log/messages
log_group_name = bastion
[/var/log/secure]
datetime_format = %b %d %H:%M:%S
file = /var/log/secure
log_stream_name = {instance_id}/var/log/secure
log_group_name = bastion" > /etc/awslogs/awslogs.conf

echo "[plugins]
cwlogs = cwlogs
[default]
region = ${region}" > /etc/awslogs/awscli.conf

service awslogs start
chkconfig awslogs on
service yum-cron start
chkconfig yum-cron on

# Signal to the ASG that this instance is ready to be put into service and can be taken out of Pending:Wait
aws autoscaling complete-lifecycle-action \
    --lifecycle-action-result CONTINUE \
    --instance-id $INSTANCE_ID \
    --lifecycle-hook-name "auto-scaling-launch-hook" \
    --auto-scaling-group-name "bastion" \
    --region ${region}
