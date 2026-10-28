# Copy to terraform.tfvars (gitignored) for local plan/apply runs.
# region, app_name, desired_count, image_tag, db_host, db_name, db_user and
# postgres_image all have defaults.
allowed_cidr = "0.0.0.0/32" # your public IP, e.g. "203.0.113.4/32"
db_password  = "localpass"
