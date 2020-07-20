provider "aws" {
  region = var.region
}

data "template_file" "role" {
  template = file("${path.module}/templates/role.json")
}

data "template_file" "policy" {
  template = file("${path.module}/templates/policy.json")

  vars = {
    CLIENT = var.client_name
  }
}

resource "aws_iam_role" "cost_utilization_report_role" {
  name               = "cost_utilization_report_role"
  assume_role_policy = data.template_file.role.rendered
}

resource "aws_iam_role_policy" "cost_utilization_report_policy" {
  name   = "cost_utilization_report_policy"
  policy = data.template_file.policy.rendered
  role   = aws_iam_role.cost_utilization_report_role.id
}

resource "aws_s3_bucket" "cost_utilization_s3" {
  bucket = "ea-cost-utilization-s3"

  versioning {
    enabled = "true"
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  tags = {
    name                  = "cost_utilization_${var.client_name}"
    environment           = var.tag_environment
    tag_deployment_method = var.tag_deployment_method
  }
}

data "archive_file" "cost_utilization_source_archive" {
  type        = "zip"
  source_file = "${path.module}/cost_utilization.py"
  output_path = "${path.module}/${var.lambda_zip_file_name}"
}

resource "aws_s3_bucket_object" "cost_utilizqtion_archive" {
  bucket     = aws_s3_bucket.cost_utilization_s3.bucket
  key        = "lambda/${var.lambda_zip_file_name}"
  source     = "${path.module}/${var.lambda_zip_file_name}"
  etag       = data.archive_file.cost_utilization_source_archive.output_md5
  depends_on = ["data.archive_file.cost_utilization_source_archive"]
}

resource "aws_lambda_function" "cost_utilization_lambda" {
  filename      = data.archive_file.cost_utilization_source_archive.output_path
  function_name = "cost_utilization"
  timeout       = var.lambda_timeout
  role          = aws_iam_role.cost_utilization_report_role.arn
  handler       = "cost_utilization.lambda_handler"
  runtime       = "python3.7"
  depends_on    = ["aws_s3_bucket_object.cost_utilizqtion_archive"]

  environment {
    variables = {
      SENDER      = var.ses_sender
      SUBJECT     = var.ses_subject
      RECIPIENT   = var.ses_recipient
      BUCKET_NAME = aws_s3_bucket.cost_utilization_s3.bucket
      CLIENT      = var.client_name
    }
  }

  tags = {
    name                  = "cost_utilization_lambda"
    environment           = var.tag_environment
    tag_deployment_method = var.tag_deployment_method
  }
}

resource "aws_cloudwatch_event_rule" "last_day_of_the_month" {
  name                = "last-day-of-the_month"
  description         = "schedule for last day of the month at 23:59"
  schedule_expression = var.cron_job
}

resource "aws_cloudwatch_event_target" "last_day_of_the_month_target" {
  rule      = aws_cloudwatch_event_rule.last_day_of_the_month.name
  target_id = "cost_explorer"
  arn       = aws_lambda_function.cost_utilization_lambda.arn
}

resource "aws_lambda_permission" "allow_execution_of_target" {
  statement_id  = "AllowExecutionFromCloudWatch"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.cost_utilization_lambda.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.last_day_of_the_month.arn
}
