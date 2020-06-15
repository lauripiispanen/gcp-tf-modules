variable "slack_webhook_url" {
  type = string
}

variable "source_bucket_location" {
  type = string
  default = "EUROPE-WEST1"
}

variable "cloud_function_region" {
  type = string
  default = "europe-west1"
}

variable "cloud_function_memory_mb" {
    type = number
    default = 128
}

variable "project_id" {
    type = string
    default = ""
}

locals {
    project_id = var.project_id != "" ? var.project_id : data.google_client_config.default.project
}

data "google_client_config" "default" {}

resource "google_storage_bucket" "bucket" {
  location = var.source_bucket_location
  name = "${local.project_id}-cloud-functions"
}

data "archive_file" "slack_notification_function" {
  type        = "zip"
  source_dir = "${path.module}/cloud-function-source"
  output_path = "${path.module}/cf-slack-dist.zip"
}

resource "google_storage_bucket_object" "archive" {
  name   = "slack_notification.zip"
  bucket = google_storage_bucket.bucket.name
  source = data.archive_file.slack_notification_function.output_path
}

resource "google_cloudfunctions_function" "build_notifications_to_slack" {
  name        = "buildNotificationsToSlack"
  description = "Sends GCB notifications to slack"
  runtime     = "nodejs10"
  entry_point = "buildNotificationsToSlack"
  labels = {}

  available_memory_mb   = var.cloud_function_memory_mb
  source_archive_bucket = google_storage_bucket.bucket.name
  source_archive_object = google_storage_bucket_object.archive.name
  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource = "projects/${local.project_id}/topics/cloud-builds"
  }
  environment_variables = {
    SLACK_WEBHOOK_URL = var.slack_webhook_url
  }
  region = var.cloud_function_region
}
