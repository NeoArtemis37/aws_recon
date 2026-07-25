# Changelog

All notable changes to this project will be documented in this file.

## [2.0.0] - 2024-07

### Added
- Automated privilege escalation engine (SSM → AssumeRole → S3 chain)
- EC2 user-data extraction with base64 decoding
- DynamoDB table scanning (up to 10 items per table)
- ECS cluster and task enumeration with env var extraction
- API Gateway REST API and resource mapping
- SQS queue and SNS topic enumeration
- CloudWatch log group and stream event retrieval
- Version-aware S3 manifest retrieval (`--version-id` support)
- Banner with ASCII art and author attribution
- ANSI color-coded output (red/green/cyan)

### Changed
- Refactored all task functions to use modular `task_*` pattern
- Added `set -uo pipefail` for safer execution
- Added python3 dependency check at startup
- Improved error handling — all AWS calls silently fail per-service

### Removed
- (None)

## [1.0.0] - 2024-06

### Added
- Initial release
- Basic IAM identity enumeration
- S3 bucket and object listing
- Secrets Manager enumeration
- SSM parameter extraction
- Lambda function configuration retrieval
- CloudFormation stack output extraction
