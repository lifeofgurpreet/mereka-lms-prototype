resource "google_billing_budget" "mereka_monthly" {
  provider        = google-beta
  billing_account = var.billing_account_id
  display_name    = "mereka-lms-monthly"

  amount {
    specified_amount {
      currency_code = "MYR"
      units         = tostring(var.monthly_budget_myr)
    }
  }

  budget_filter {
    projects = ["projects/${var.project_id}"]
  }

  dynamic "threshold_rules" {
    for_each = var.budget_thresholds
    content {
      threshold_percent = threshold_rules.value
      spend_basis       = threshold_rules.value >= 1 ? "FORECASTED_SPEND" : "CURRENT_SPEND"
    }
  }

  all_updates_rule {
    monitoring_notification_channels = var.budget_monitoring_channels
    disable_default_iam_recipients   = false
  }
}
