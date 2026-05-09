project = "shopxpress-pro"
env     = "dev"
region  = "ap-southeast-1"

# Cluster
cluster_name                 = "shopxpress-pro-nonprd-eks"
cluster_version              = "1.34"
endpoint_public_access_cidrs = ["113.22.28.87/32"]
cluster_enabled_log_types    = ["api", "audit"]
cluster_log_retention_days   = 30

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
