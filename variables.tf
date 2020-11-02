variable "name" {
  description = "API name"
  type = string
}

variable "domain_name" {
  description = "API domain name"
  type = string
  default = null
}

variable "domain_certificate_arn" {
  description = "ACM certificate ARN"
  type = string
  default = null
}

variable "stage" {
  description = "API deployment stage (e.g. dev)"
  type = string
}

variable "functions" {
  description = "API Lambda functions"
  type = map(object({
    description = string
    method = string
    filename = string
    timeout = number
    runtime = string
    handler = string
    memory_size = string
    iam_role_policy = string
    subnet_ids = list(string)
    security_group_ids = list(string)
  }))
  default = {}
}
