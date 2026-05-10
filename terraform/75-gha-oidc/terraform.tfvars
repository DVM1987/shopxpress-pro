project = "shopxpress-pro"
env     = "nonprd"
region  = "ap-southeast-1"

# GitHub OIDC config
github_org            = "DVM1987"
github_repo           = "shopxpress-pro-app"
github_branch_pattern = "*"
oidc_provider_url     = "https://token.actions.githubusercontent.com"
oidc_audience         = "sts.amazonaws.com"

# Read remote state
tfstate_bucket = "shopxpress-pro-tfstate-527055790396-apse1"

# Tagging
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
