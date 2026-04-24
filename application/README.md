#  Production-Grade AWS Three-Tier Web Application Infrastructure (Bitbucket + AWS)

## Project Overview

This project implements a secure, automated CI/CD pipeline using:

- Bitbucket Pipelines (Self-hosted Runner)

- Trivy for security scanning

- Amazon S3 for artifact storage

- AWS Systems Manager (SSM) for remote command execution

- Amazon EC2 for application deployment

---

## Pipeline Workflow

The pipeline performs the following stages:

- Security scanning

- Artifact packaging (versioned by Git tag)

- Upload to S3

- Deployment to EC2 via SSM

---

## Security Stage – Trivy Scan

**Step:** trivy-scan

This step scans the repository filesystem for:

- Vulnerabilities (HIGH, CRITICAL)

- Hardcoded secrets

```Bash
trivy fs \
  --scanners vuln,secret \
  --severity HIGH,CRITICAL \
  --exit-code 1 \
  .
  ```


### What It Does

- Scans the entire repo

- Fails pipeline if HIGH or CRITICAL vulnerabilities are found

- Prevents insecure code from reaching production

---

## Build Stage – Artifact Creation

### Step: build-artifact

#### Step Definition

```YAML
- step: &build-artifact
```
- step: → Defines a new pipeline step.

- &build-artifact → This is a YAML anchor.

```YAML
name: Build Web Artifact (Latest Tag)
```
- This is the display name of the step. It appears in the Bitbucket Pipelines UI.
---

#### Runner Configuration

```YAML
runs-on:
  - self.hosted
  - linux.shell
  - devrunner
  ```
This tells Bitbucket where to execute the job.

- self.hosted → The job runs on own machine/server (not Bitbucket cloud runner).

- linux.shell → It runs on a Linux OS using shell execution.

- devrunner → This is the label of self-hosted runner.
---

#### Script Section

```YAML
- git fetch --tags https://$BITBUCKET_USER:$BITBUCKET_PASS@bitbucket.org/adeolaoriade/application_codes.git
```
**What this does:**

- Fetches all Git tags from the remote repository.

- Uses authentication variables:

    - $BITBUCKET_USER

    - $BITBUCKET_PASS

**Why needed?**

Because:

- git describe --tags only works if tags exist locally.

- This ensures runner has the latest tags.

```YAML
- TAG=$(git describe --tags --abbrev=0)
```
**What this does:**

- Finds the latest Git tag.

- --tags → search annotated & lightweight tags

- --abbrev=0 → return only the tag name (not commit hash)

- Example result: 
    - v1.2.3

It stores the result into a variable: 

    - TAG=v1.2.3

Now $TAG can be reused.

---

#### Creating the Artifact

```YAML
- tar -czf "$TAG.tar.gz" -C App_repo .
```

**Breakdown:**

- tar → archive utility

- -c → create archive

- -z → gzip compress

- -f → filename

Creates a compressed archive:

    - v1.2.3.tar.gz
---

```YAML
-C App_repo .
```

**This means:**

- Change directory to App_repo

- Archive everything inside (.)

- Packaging the entire App_repo directory into a compressed artifact.

```YAML
- ls -lh "$TAG.tar.gz"
```

**Lists the file:**

- -l → long format

- -h → human-readable size

Example output:

```CODE
    -rw-r--r-- 1 runner 25M v1.2.3.tar.gz
   ```
**Useful for verifying:**

- File exists

- File size looks correct

---

#### Uploading to S3

```YAML
- aws s3 cp "$TAG.tar.gz" s3://$S3_BUCKET_NAME/artifacts/$TAG/$TAG.tar.gz
```
This uploads the artifact to Amazon S3.

**Breakdown:**

- aws s3 cp → copy file to S3

- $S3_BUCKET_NAME → environment variable

- artifacts/$TAG/ → folder structure by version

Example final path:

```YAML
s3://my-bucket/artifacts/v1.2.3/v1.2.3.tar.gz
```
---

#### Artifacts Section

```YAML
artifacts:
  - "*.tar.gz"
```

**This tells Bitbucket:**

- Save any .tar.gz file generated in this step

- Make it available to:

    - Later pipeline steps

    - Download from pipeline UI

- Even though uploading to S3, this gives:

    - Backup copy in pipeline

    - Easier debugging

    ---

## Bitbucket Pipeline Step — Deploy Code to EC2 (Detailed Explanation)

### Script Section

Everything under script: runs sequentially as shell commands.

### Fetch Git Tags

```YAML
- git fetch --tags https://$BITBUCKET_USER:$BITBUCKET_PASS@bitbucket.org/adeolaoriade/application_codes.git
```

**What it does**

- Fetches all Git tags from the remote repository.

- Uses authentication variables:

    - $BITBUCKET_USER

    - $BITBUCKET_PASS

- The next command (git describe) requires local tags to determine the latest release version.

### Get Latest Tag

```YAML
- TAG=$(git describe --tags --abbrev=0)
```

**What this does**

- Finds the latest Git tag.

- --tags → considers all tags.

- --abbrev=0 → returns only the tag name (not commit hash).

Example:

    - v1.3.0

This value is stored in:

    - $TAG

---

## Main Deployment Block (SSM Command)

```YAML
- |
```

The **|** symbol means:

- This is a **multi-line shell block.**

- Everything below it is treated as one command.

## AWS SSM Send Command

```BASH
aws ssm send-command \
```
This uses AWS CLI to send a remote command to EC2 via **Amazon Web Services Systems Manager (SSM)**. No **SSH** required.

## Amazon Web Services Systems Manager (SSM)

```BASH
--document-name "AWS-RunShellScript" \
```

- Uses the predefined SSM document:

**AWS-RunShellScript**

- This allows execution of shell commands on the EC2 instance.

```BASH
--targets "Key=tag:Name,Values=webapp-instance" \
```

**What this does**

Targets EC2 instances using **tags.**

It selects any instance with:

```BASH
Name = webapp-instance
```

This is safer than hardcoding instance IDs.

```BASH
--parameters commands="[ ... ]" \
```

This section contains all commands that will run on the EC2 instance. Each line inside is executed sequentially.

---

## Commands Executed on EC2

### 1. Enable Immediate Failure

```BASH
"set -e",
```

### 2. Create Application Directory

```BASH
"sudo mkdir -p /opt/webapp",
```

### 3. Download Artifact from S3

```BASH
"sudo aws s3 cp s3://${S3_BUCKET_NAME}/artifacts/${TAG}/${TAG}.tar.gz /opt/webapp/app.tar.gz",
```

### 4. Change Directory

```BASH
"cd /opt/webapp",
```

### 5. Extract Artifact


```BASH
"sudo tar -xzf app.tar.gz",
```

- Extracts compressed archive.

- -x → extract

- -z → gzip

- -f → file

### 6. Remove Archive

```BASH
"rm -f app.tar.gz",
```

### 7. Clear Old Web Files

```BASH
"rm -rf /var/www/html/*",
```

### 8. Copy New Files

```BASH
"sudo cp -r ./* /var/www/html/",
```

Copies new extracted application files into:

**/var/www/html**

This is typically the default Apache web root.

### 9. Fix Ownership

```BASH
"sudo chown -R apache:apache /var/www/html",
```

### 10. Set Permissions

```BASH
"sudo chmod -R 755 /var/www/html",
```

- Sets directory permissions.

- 755 means:

    - Owner: full access

    - Group: read + execute

    - Others: read + execute

### 11. Reload Apache

```BASH
"sudo systemctl reload httpd"
```

- Reloads Apache service.

- Applies new changes.

- No full restart needed.

```BASH
--timeout-seconds 600
```

- Sets timeout to 600 seconds (10 minutes).

- Prevents infinite hanging.