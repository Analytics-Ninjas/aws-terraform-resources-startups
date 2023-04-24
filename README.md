# Prerequisites
- [Terraform](https://developer.hashicorp.com/terraform/downloads)
- [Git](https://git-scm.com/downloads)
- An IDE of your choice

# Get Started
1. Download root acces key on AWS console.
  - `AWS account (Drop Down Menu)` > `Security Credentials` > `Create Access Key`
2. Clone the repo
3. Fill in the your access key and secrey access key in `main.tf` file
4. Execute (For `Windows` user, install [WSL](https://learn.microsoft.com/en-us/windows/wsl/install) first then execute with your distro terminal.
  - `terraform init`
  - `terraform apply -auto-approve`
