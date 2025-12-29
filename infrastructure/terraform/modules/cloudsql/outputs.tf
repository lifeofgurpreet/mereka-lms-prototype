output "instance_connection_name" {
  value = google_sql_database_instance.mysql.connection_name
}

output "instance_private_ip" {
  value = google_sql_database_instance.mysql.private_ip_address
}
