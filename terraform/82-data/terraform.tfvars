project = "shopxpress-pro"
env     = "dev"
region  = "ap-southeast-1"

# Bitnami PostgreSQL chart — pin version
postgresql_chart_version    = "18.6.4"
postgresql_image_repository = "bitnamilegacy/postgresql"
postgresql_image_tag        = "17.6.0-debian-12-r4"
data_namespace              = "shopxpress-data"
storage_class_name          = "gp3"
helm_timeout_seconds        = 600

# Secrets Manager
secret_name_prefix          = "shopxpress-pro"
secret_recovery_window_days = 0

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
