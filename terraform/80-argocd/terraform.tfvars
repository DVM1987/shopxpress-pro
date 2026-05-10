project = "shopxpress-pro"
env     = "nonprd"
region  = "ap-southeast-1"

# Helm release config
argocd_chart_version        = "9.5.12"
argocd_helm_timeout_seconds = 600

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
