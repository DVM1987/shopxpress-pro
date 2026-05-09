project = "shopxpress-pro"
env     = "dev"
region  = "ap-southeast-1"

# Node group
node_group_name = "default"
instance_types  = ["t3.medium"]
capacity_type   = "ON_DEMAND"
ami_type        = "AL2023_x86_64_STANDARD"
disk_size_gb    = 50
min_size        = 3
max_size        = 6
desired_size    = 3
max_pods        = 110

node_labels = {
  role     = "general"
  capacity = "on-demand"
}

# Tagging — governance / finops / audit
owner               = "DE000189"
cost_center         = "engineering"
repo_url            = "https://github.com/DVM1987/shopxpress-pro"
data_classification = "confidential"
backup_policy       = "none"
created_by          = "DE000189"
