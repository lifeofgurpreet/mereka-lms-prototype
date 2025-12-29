output "primary_host" {
  value = google_redis_instance.redis.host
}

output "primary_port" {
  value = google_redis_instance.redis.port
}
