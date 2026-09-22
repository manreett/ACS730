# Lab 1: Git, GitHub and the AWS CLI

## Script Descriptions
- `create-security-group.sh`: Finds my public IP and makes a security group allowing SSH only from my /32 IP.
- `create-instance.sh`: Grabs the latest AL2023 AMI from SSM and launches a t3.micro with LabInstanceProfile attached.
- `delete-instance.sh`: Finds any acs730-week1 instances and terminates them, exiting cleanly if none are found.
- `delete-security-group.sh`: Deletes the acs730-week1-sg security group by name.

## Experiments

### Experiment 2: /32 vs /24
- Prediction: Changing /32 to /24 will allow 256 IPs to connect instead of just mine.
- Observation: Checking the SG rules showed the CIDR as .0/24 on port 22.
- Explanation: Other students on the same campus Wi-Fi subnet share that /24 block, so this gives everyone around me SSH access and breaks least privilege.

### Experiment 3: Idempotent-ish deletes
- Prediction: Running the delete script twice will shut down instances on the first try and do nothing on the second.
- Observation: The first run terminated the instance, and the second run printed "Nothing to delete." with exit code 0.
- Explanation: The `if [ -z "$IDS" ]` check stops the script from running `aws ec2 terminate-instances` with no instance ID, preventing a CLI syntax error under `set -e`.


