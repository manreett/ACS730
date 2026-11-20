# Lab 6 — Ansible Configuration Management and Golden AMIs

## Required Architecture & Hygiene Answers

- **Runner-to-instance mechanism:** We used **AWS Systems Manager Session Manager (`aws_ssm`)** because the SSM agent inside each EC2 instance dials outbound over HTTPS (port 443) using `LabInstanceProfile`, avoiding any inbound port 22 rule or long-lived private SSH key stored in GitHub repository secrets.
- **What `changed=0` on a second run proves:** A `changed=0` recap proves that every Ansible module inspected the actual state of the target host and verified it already matched the desired configuration—not that the playbook skipped work—making the role safe to re-run repeatedly on both fresh and already-converged servers in CI/CD pipelines.
- **Why deregistering an AMI is not enough:** An AMI is only a metadata pointer to an underlying EBS snapshot, so deregistering the image leaves the EBS snapshot behind incurring storage charges, and once the AMI is gone `aws ec2 describe-images` can no longer identify which snapshot belonged to it.

---

## Boot-to-Ready Comparison

| Provisioning Path | Measured Time | What Is Included in the Stopwatch |
| :--- | :---: | :--- |
| **Converge-on-Boot** (`converge-on-boot`) | **104 seconds** | EC2 API launch, OS boot, SSM agent registration loop, S3 staging + `ansible-playbook` (`dnf` package install, user/file setup, template rendering, systemd service start), and HTTP 200 response. |
| **Golden AMI** (`golden-ami`) | **92 seconds** | EC2 API launch from pre-baked AMI (`ami-00b4d783117d08cc1`), OS boot, and automatic systemd startup of the already-installed `acs730-web` service until HTTP 200 response. |

### Analysis & Trade-Offs

- **Where the time went in the slow path:** In `converge-on-boot`, most time is spent outside Ansible's YAML logic—waiting for the EC2 instance's SSM agent to finish registering with AWS Systems Manager (`PingStatus: Online`), staging module payloads through the `us-east-1` S3 bucket (`acs730-lab6-ssm-<account-id>`), and pulling `dnf` packages over the network on every launch.
- **Cost shifted rather than removed:** Baking a Golden AMI moves configuration time from **N** launch events to **one** upfront Packer build (~5 minutes 33 seconds). Launching a single server pays a higher total upfront cost with Packer, whereas launching a fleet or autoscaling group wins immediately because every node skips post-boot package installation and SSM convergence.
- **What breaks with Golden AMIs:** An AMI is a frozen snapshot in time—OS security patches and application updates released after the bake are missing until you rebuild on a scheduled cadence, and inspecting what is inside requires reading the Packer template or build log rather than self-documenting idempotent playbooks.
- **What breaks with Converge-on-Boot:** Every boot depends on external package repositories (`dnf` mirrors) and S3/SSM control-plane availability at launch time; a mirror outage or transient SSM delay during a 3:00 a.m. autoscaling event prevents new instances from becoming ready.
- **SSM S3 bucket & region constraint:** The `aws_ssm` connection plugin transfers files via an S3 staging bucket (`ansible_aws_ssm_bucket_name`) that must exist in the exact same region (`us-east-1`) configured in `ansible_aws_ssm_region`, or the first task fails with `PermanentRedirect`.

### Recommendation

We recommend using **Golden AMIs** for production web fleets because we launch multiple instances and want fast, deterministic boots free of external `dnf` mirror dependencies, though we would switch to **converge-on-boot** for single-node environments or rapidly changing development builds where paying a ~5.5-minute Packer bake per change is slower than converging once.

---

## Experiments

### 1. Breaking Idempotency with `ansible.builtin.shell` vs. `creates:`
- **Prediction:** Adding `ansible.builtin.shell: mkdir -p /opt/acs730-web/logs` will cause the second consecutive run to report `changed=1` on both hosts, whereas adding `args: creates: /opt/acs730-web/logs` will return the second run to `changed=0`.
- **Result & Explanation:** As predicted, the bare `shell` task reported `changed=1` (`ok=8`) on both runs, and adding `creates: /opt/acs730-web/logs` restored `changed=0` (`ok=8`). Ansible cannot infer idempotency for `shell` commands on its own because arbitrary shell strings are opaque commands with no built-in state inspection, unlike declarative modules such as `ansible.builtin.file`.

### 2. `state: latest` vs. `state: present` on `ansible.builtin.dnf`
- **Prediction:** Switching `dnf` to `state: latest` will report `changed=0` on a second immediate run unless upstream repositories publish a newer package version that day.
- **Result & Explanation:** Both runs reported `changed=0` (`ok=7`) because no newer `python3` or `rsync` RPMs were released during the test window, though the result depends on the day upstream updates land. In a CI/CD pipeline that runs on every merge, `state: present` is preferred over `state: latest` because unpinned automatic upgrades can introduce unexpected breaking changes or non-deterministic behavior mid-deployment.
