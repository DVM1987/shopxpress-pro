project = "shopxpress-pro"
env     = "nonprd"
region  = "ap-southeast-1"

# Repo settings
services             = ["gateway", "products", "orders"]
image_tag_mutability = "IMMUTABLE"
encryption_type      = "AES256"
force_delete         = true # Lab A++ allow destroy nhanh; PROD nên false

# Lifecycle policy
lifecycle_keep_count    = 10
lifecycle_untagged_days = 1
lifecycle_tag_patterns  = ["dev*", "stg*", "prd*", "v*"]

# Registry-level scanning
registry_scan_type   = "BASIC"
registry_scan_filter = "*"

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
