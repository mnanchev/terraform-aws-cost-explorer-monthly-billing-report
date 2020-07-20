module "cost_explorer" {
  source          = "../"
  client_name     = "bear-pooh"
  cron_job        = "cron(0 10 1 * ? *)"
  tag_environment = "master"
  lambda_timeout  = "300"
  region          = "eu-west-1"
  ses_recipient   = ""
  ses_sender      = "support@email.com"
  ses_subject     = "cost utilization"
}
