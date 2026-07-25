<p align="center">
  <img src="assets/logo.png" alt="ARTEMIS AWS Recon" width="200"/>
</p>

<h1 align="center">
  <a href="https://github.com/NeoArtemis37/aws-recon">ARTEMIS AWS Recon</a>
</h1>

<p align="center">
  <b>Comprehensive AWS Post-Exploitation Reconnaissance & Privilege Escalation Framework</b>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Version-2.0-red?style=for-the-badge" alt="Version"/>
  <img src="https://img.shields.io/badge/Platform-Linux%20%7C%20macOS-brightgreen?style=for-the-badge" alt="Platform"/>
  <img src="https://img.shields.io/badge/Shell-Bash_4.0%2B-4EAA25?style=for-the-badge" alt="Shell"/>
  <img src="https://img.shields.io/badge/AWS_CLI-v2-required-blue?style=for-the-badge" alt="AWS CLI"/>
  <img src="https://img.shields.io/badge/Purpose-Education-yellow?style=for-the-badge" alt="Purpose"/>
  <img src="https://img.shields.io/badge/License-MIT-orange?style=for-the-badge" alt="License"/>
</p>

<p align="center">
  <a href="#features">Features</a> &bull;
  <a href="#installation">Installation</a> &bull;
  <a href="#usage">Usage</a> &bull;
  <a href="#services-enumerated">Services Enumerated</a> &bull;
  <a href="#privesc-engine">Privesc Engine</a> &bull;
  <a href="#examples">Examples</a> &bull;
  <a href="#disclaimer">Disclaimer</a>
</p>

<p align="center">
  <img src="assets/banner.png" alt="ARTEMIS Banner" width="900"/>
</p>

---

## 🎯 Overview

**ARTEMIS AWS Recon** is a lightweight, single-file Bash framework designed for authorized AWS security assessments. It automates the enumeration of **12+ AWS services** from a set of compromised credentials, extracts secrets and sensitive data, and features a **built-in privilege escalation engine** that chains SSM parameter extraction with STS AssumeRole to escalate access and exfiltrate restricted S3 objects — all in a single, zero-dependency pass (aside from `aws` CLI and `python3`).

The tool is engineered for speed, stealth, and comprehensive coverage — ideal for penetration testers, bug bounty hunters, and cloud security engineers conducting authorized assessments.

---

## ✨ Features

| Category | Details |
|---|---|
| **13 Service Modules** | IAM, STS, S3, Secrets Manager, SSM, Lambda, DynamoDB, EC2, CloudFormation, ECS, API Gateway, SQS/SNS, CloudWatch Logs |
| **Auto Privesc Engine** | Extracts role ARNs & external IDs from SSM, chains `sts:AssumeRole` to escalate, then exfiltrates restricted S3 manifests |
| **Parallel Task Runner** | Each service enumerated independently with live spinner feedback |
| **Zero Config** | Single binary — no external config files, no databases, no frameworks |
| **Credential Forwarding** | Temporary assumed-role credentials automatically used for escalated operations |
| **S3 Deep Scan** | Lists buckets, enumerates objects, and extracts first 500 bytes of each file |
| **Secret Extraction** | Automatically decrypts and dumps Secrets Manager values |
| **EC2 User Data** | Retrieves and decodes EC2 instance user-data payloads |
| **Version-Aware S3** | Supports `--version-id` for manifest retrieval from versioned buckets |
| **Colored Output** | ANSI color-coded results — red for critical, green for successes, cyan for data |
| **Offline Capable** | Works against any AWS-compatible endpoint (LocalStack, Moto, custom) |

---

## 📦 Installation

### Prerequisites

```bash
# AWS CLI v2 (required)
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Python 3 (required — usually pre-installed)
python3 --version
```

### Clone & Run

```bash
git clone https://github.com/NeoArtemis37/aws-recon.git
cd aws-recon
chmod +x aws_recon.sh
```

### Quick Start

```bash
./aws_recon.sh \
  -a AKIAT6DSPGXXXXXXXXXX \
  -s 743LpZXXXXXXXXXXXXXXXXXXXXXXXXXX \
  -r us-east-1 \
  -u https://your-aws-endpoint.example.com
```

> **Note**: Replace the endpoint URL with your target AWS endpoint or a local emulator like LocalStack (`http://localhost:4566`).

---

## 🚀 Usage

```
Usage: ./aws_recon.sh -a <AccessKey> -s <SecretKey> -r <Region> -u <EndpointURL>

Required Arguments:
  -a    AWS Access Key ID
  -s    AWS Secret Access Key
  -r    AWS Region (e.g., us-east-1, eu-west-2, ap-southeast-1)
  -u    Endpoint URL (AWS endpoint or compatible emulator)

Example:
  ./aws_recon.sh -a AKIA... -s 743L... -r us-east-1 -u http://154.57.164.76:31836
```

### Environment Variables

All credentials are set as environment variables before enumeration, making it safe to chain with other tools:

```bash
export AWS_ACCESS_KEY_ID=AKIA...
export AWS_SECRET_ACCESS_KEY=743L...
export AWS_DEFAULT_REGION=us-east-1

# Then run against the real AWS (no -u needed)
# Modify the script to use real AWS endpoint when testing against your own account
```

---

## 🔍 Services Enumerated

### 1. Identity & IAM
- Caller identity (ARN, user, account)
- Inline IAM policies per user
- Attached managed policies
- All IAM roles in the account

### 2. S3 Buckets & Objects
- Complete bucket inventory
- Full object listing per bucket
- **Content preview** — first 500 bytes of each object extracted

### 3. AWS Secrets Manager
- Secret enumeration
- Automatic value decryption and display

### 4. SSM Parameter Store
- All parameters listed
- Decrypted values retrieved with `--with-decryption`

### 5. Lambda Functions
- Function inventory
- Environment variables extracted
- Resource-based policies dumped

### 6. DynamoDB
- Table inventory
- **Data sampling** — up to 10 items scanned per table

### 7. EC2 Instances
- Instance listing
- **User-data extraction and base64 decoding**

### 8. CloudFormation
- Stack inventory
- Output values extraction (often contain secrets)

### 9. ECS Clusters
- Cluster enumeration
- Task listing and container environment variables

### 10. API Gateway
- REST API inventory
- Resource paths and HTTP methods

### 11. SQS & SNS
- Queue URL enumeration
- Topic ARN enumeration

### 12. CloudWatch Logs
- Log group enumeration
- Latest stream events from each group

### 13. Automated Privilege Escalation (Bonus)
- See [Privesc Engine](#privesc-engine) below

---

## ⚡ Privesc Engine

The built-in privilege escalation engine is the crown jewel of ARTEMIS. It automatically:

```
1. Enumerates all SSM parameters
2. Parses each value for:
     ├── scanner_role_arn    → Target role to assume
     ├── scanner_external_id → External ID for AssumeRole
     ├── manifest_bucket     → Restricted S3 bucket
     ├── manifest_object_key → Restricted S3 object
     └── manifest_version_id → Specific object version (if set)
3. Calls sts:AssumeRole with discovered credentials
4. Exfiltrates the restricted S3 object using temporary elevated credentials
```

**Attack Chain Visualized:**

```
SSM Parameter (decrypted)
         │
         ▼
   ┌──────────────┐
   │ Parse JSON   │──► role_arn + external_id
   └──────────────┘
         │
         ▼
   ┌──────────────┐
   │ sts:Assume   │──► Temporary elevated creds
   │   Role       │     (AccessKey + SecretKey + SessionToken)
   └──────────────┘
         │
         ▼
   ┌──────────────┐
   │ s3:GetObject │──► Restricted manifest/data exfiltrated
   │   (versioned)│
   └──────────────┘
```

This technique exploits a common misconfiguration where scanner/integration roles are stored in SSM with their external IDs, enabling an attacker who can read SSM parameters to chain into cross-account access.

---

## 📸 Examples & Screenshots

### Demo Output

<p align="center">
  <img src="assets/demo_output.png" alt="ARTEMIS Demo Output" width="900"/>
</p>

### Sample Run Against LocalStack

```bash
$ ./aws_recon.sh -a test -b test -r us-east-1 -u http://localhost:4566

     ___                     _
    / _ \  ___  ___  ___  __| | ___
   | | | |/ _ \/ __|/ _ \/ _` |/ _ \
   | |_| |  __/\__ \  __/ (_| |  __/
    \__\_\\___||___/\___|\__,_|\___|

           [ made by artemis37 ]
     [ only for educational purposes ]

Target: http://localhost:4566
Region: us-east-1
==================================================

[+] Identity & IAM
  Caller Arn: arn:aws:iam::000000000000:user/test-user
  Inline Policies:
    - AdminPolicy
  Attached Policies:
    - AdministratorAccess
  IAM Roles:
    - scanner-role
    - lambda-exec-role

[+] S3 Buckets & Objects
  Bucket: sensitive-data-bucket
    - config/secrets.yaml
      [Content]: api_key: sk-live-xxxxx...
    - backups/db_dump.sql.gz

[+] Secrets Manager
  Secret: prod/database/password
    Value: {"password":"Sup3rS3cr3t!"}

[+] SSM Parameters
  Parameter: /scanner/config
    Value: {"scanner_role_arn":"arn:aws:iam::123456789012:role/scanner-role","scanner_external_id":"ext-id-abc123",...}

[+] Automated Privesc Check
  [!] Privilege Escalation Path Found in SSM!
  Role: arn:aws:iam::123456789012:role/scanner-role
  External ID: ext-id-abc123
  Attempting to assume role...
  [+] Successfully assumed role!
  Attempting to download restricted S3 object using assumed role...
  [RESTRICTED FILE CONTENT]:
  <manifest content here...>

==================================================
[+] Recon Complete.
```

---

## 🛠 Development

### Project Structure

```
aws-recon/
├── aws_recon.sh          # Main recon script (single-file tool)
├── README.md             # This file
├── LICENSE               # MIT License
├── .gitignore            # Git ignore rules
├── assets/
│   ├── logo.png          # Tool logo
│   ├── banner.png        # Social card banner
│   └── demo_output.png   # Demo screenshot
├── docs/
│   ├── ATTACK_SURFACE.md # Detailed attack surface analysis
│   ├── CHANGELIST.md      # Version changelog
│   └── REFERENCES.md     # AWS security references
└── .github/
    └── workflows/
        └── lint.yml       # ShellCheck CI
```

### Adding New Modules

The modular `task_*` function pattern makes it trivial to add new services:

```bash
# Add a new recon module
task_rds() {
    INSTANCES=$(aws rds describe-db-instances $EP 2>/dev/null | python3 -c "import sys,json; [print(i['DBInstanceIdentifier']) for i in json.load(sys.stdin).get('DBInstances',[])]" 2>/dev/null)
    if [ -n "$INSTANCES" ]; then
        echo "$INSTANCES" | while read -r DB; do
            echo "  RDS Instance: $DB"
        done
    else
        echo "  No RDS instances found or access denied."
    fi
}

# Register it in the execution flow
run_task "RDS Instances" task_rds
```

### Shell Linting

```bash
# Install ShellCheck
sudo apt install shellcheck

# Lint the script
shellcheck aws_recon.sh
```

---

## 📋 MITRE ATT&CK Mapping

| Tactic | Technique | ID | Covered By |
|---|---|---|---|
| Discovery | Cloud Infrastructure Recon | T1526 | All task modules |
| Discovery | Cloud Service Discovery | T1527 | API Gateway, ECS, Lambda |
| Credential Access | Steal Application Access Token | T1539 | Secrets Manager, SSM |
| Credential Access | Unsecured Credentials | T1552 | S3 content extraction |
| Collection | Data from Cloud Storage Object | T1530 | S3 deep scan |
| Collection | Email Collection | T1114 | S3 content preview |
| Privilege Escalation | Valid Accounts | T1078 | Privesc engine |
| Privilege Escalation | Abuse Elevation Control Mechanism | T1548 | SSM → AssumeRole chain |
| Execution | Cloud API | T1059.009 | All AWS CLI calls |
| Defense Evasion | Access Token Manipulation | T1550.001 | AssumeRole session tokens |

---

## 🤝 Contributing

Contributions are welcome! Please follow these steps:

1. Fork the repository
2. Create a feature branch: `git checkout -b feat/new-service`
3. Add your `task_*` function following the existing pattern
4. Ensure ShellCheck passes: `shellcheck aws_recon.sh`
5. Test against LocalStack: `docker run -d -p 4566:4566 localstack/localstack`
6. Submit a Pull Request with a clear description

---

## ⚠️ Disclaimer

This tool is provided **strictly for educational purposes and authorized security assessments only**. The author assumes no liability and is not responsible for any misuse or damage caused by this program. Always obtain explicit written permission before testing against any AWS environment. Unauthorized access to computer systems is illegal.

**By using this tool, you agree to:**
- Only use it against systems you own or have explicit authorization to test
- Comply with all applicable local, state, national, and international laws
- Hold the author harmless from any legal action resulting from misuse

---

## 📄 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  Made with 🔴 by <a href="https://github.com/artemis37">artemis37</a> | For Educational Purposes Only
</p>
