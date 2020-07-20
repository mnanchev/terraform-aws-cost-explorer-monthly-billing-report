variable "region" {
  description = "You should choose one of following reagions,because of SESavailability: us-east-1,us-west-2,eu-west-1"
}

variable "client_name" {
  description = "Client name"
}

variable "tag_environment" {
  description = "Environment for the infrastructure"
}

variable "filename" {
  description = "File name"
  default     = "cost_explorer.zip"
}

variable "lambda_timeout" {
  description = "Lambda timeout"
}

variable "cron_job" {
  description = "cron job"
}

variable "ses_sender" {
  description = "sender of the email"
}

variable "ses_subject" {
  description = "subject of the email"
}

variable "ses_recipient" {
  description = "recipient of the email"
}

variable "owner" {
  default = "Used to identify who is responsible for the resource"
}

variable "tag_deployment_method" {
  default     = "tf"
  description = "How was the module deployed"
}

variable "lambda_zip_file_name" {
  default = "cost_explorer.zip"
}
