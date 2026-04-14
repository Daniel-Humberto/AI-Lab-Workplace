# Cloud Deployment Guide

Neuralytics OS targets agnostic, cloud-ready execution via Terraform-based IaC provisioning.

### AWS EKS (Recommended)
Use `infra/terraform/modules/eks` to automatically spin up a `t3.medium` cluster.

**Command:**
```bash
cd infra/terraform
terraform init
terraform apply -var="cluster_name=neuralytics-prod"
```

**Cost Estimation:** ~$150/mo.  
Ensure GPU node groups are scaled if `ollama` workloads intensify natively versus relying on remote API calls.
