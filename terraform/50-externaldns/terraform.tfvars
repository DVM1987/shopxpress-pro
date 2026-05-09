project = "shopxpress-pro"
env     = "nonprd"
region  = "ap-southeast-1"

# Helm release config
externaldns_chart_version        = "1.21.1"
externaldns_replica_count        = 1
externaldns_helm_timeout_seconds = 600
externaldns_txt_owner_id         = "shopxpress-pro-nonprd"
externaldns_policy               = "sync"
externaldns_interval             = "1m"

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
