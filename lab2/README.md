# Lab 2 - Linux Administration and Deploying a Web App to EC2

## Overview
hows how to install an Apache HTTP server under Amazon Linux 2023, manage it through a self-made systemd unit, and check its availability after system rebooting.


## Implementation Summary

* **Service Configuration**: Created custom unit file `acs730-web.service` configured under `/etc/systemd/system/` with multi-user target dependency.
* **Permissions & Least Privilege**: Automated web server installation and ensured web assets are owned by the dedicated service user `acs730` rather than root.
* **Verification**: Verified local and external connectivity via HTTP, rebooted the EC2 instance, and confirmed automated recovery of the service.

## Difference between systemctl start and systemctl enable
The `systemctl start` command launches a service for the current session immediately , while `systemctl enable` makes sure that the service starts on its own whenever the system boots up.
