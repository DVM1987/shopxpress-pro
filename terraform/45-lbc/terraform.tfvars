project = "shopxpress-pro"
env     = "dev"
region  = "ap-southeast-1"

# Helm release config
lbc_chart_version        = "3.3.0"
lbc_replica_count        = 2
lbc_helm_timeout_seconds = 600

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
