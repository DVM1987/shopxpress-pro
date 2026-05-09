project = "shopxpress-pro"
env     = "nonprd"
region  = "ap-southeast-1"

# Helm release config
eso_chart_version        = "2.4.1"
eso_helm_timeout_seconds = 600
eso_replica_count        = 1

# Demo secret + ExternalSecret config
demo_secret_name            = "shopxpress-pro/dev/demo-eso"
demo_secret_username        = "demo"
demo_secret_password_length = 32
eso_refresh_interval        = "1m"
app_namespace               = "app-demo"

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "restricted"
backup_policy       = "none"
created_by          = "DE000189"
