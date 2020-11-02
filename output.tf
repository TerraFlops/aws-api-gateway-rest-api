output "rest_api_id" {
  description = "Rest API resource ID"
  value = aws_api_gateway_rest_api.api.id
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value = length(var.functions) > 0 ? aws_api_gateway_domain_name.domain.cloudfront_domain_name : null
}

output "cloudfront_zone_id" {
  description = "CloudFront distribution zone ID"
  value = length(var.functions) > 0 ? aws_api_gateway_domain_name.domain.cloudfront_zone_id : null
}
