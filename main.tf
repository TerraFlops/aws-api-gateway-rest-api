data "aws_region" "default" {}
data "aws_caller_identity" "default" {}

resource "aws_api_gateway_rest_api" "api" {
  name = var.name
}

resource "aws_api_gateway_resource" "proxy" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id = aws_api_gateway_rest_api.api.root_resource_id
  path_part = "{proxy+}"
}

resource "aws_api_gateway_domain_name" "domain" {
  domain_name = var.domain_name
  certificate_arn = var.domain_certificate_arn
}

resource "aws_api_gateway_deployment" "deployment" {
  count = length(var.functions) > 0 ? 1 : 0
  rest_api_id = aws_api_gateway_rest_api.api.id
  stage_name = var.stage
  variables = {
    deployed_at = formatdate("YYYYMMDDhhmmss", timestamp())
  }
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_base_path_mapping" "domain" {
  count = length(var.functions) > 0 ? 1 : 0
  api_id = aws_api_gateway_rest_api.api.id
  domain_name = aws_api_gateway_domain_name.domain.domain_name
  stage_name = var.stage
}

resource "aws_lambda_permission" "allow_api_gateway" {
  for_each = var.functions
  function_name = aws_lambda_function.lambda[each.key].arn
  statement_id = "AllowExecutionFromApiGateway"
  action = "lambda:InvokeFunction"
  principal = "apigateway.amazonaws.com"
  source_arn = "arn:aws:execute-api:${data.aws_region.default.name}:${data.aws_caller_identity.default.account_id}:${aws_api_gateway_rest_api.api.id}/*"
}

resource "aws_api_gateway_method" "request_method" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = "ANY"
  authorization = "NONE"
}


resource "aws_api_gateway_method" "request_method_root" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = "ANY"
  authorization = "NONE"
}

resource "aws_api_gateway_integration" "request_method_integration" {
  for_each = var.functions
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method.request_method.http_method
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:${data.aws_region.default.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda[each.key].arn}/invocations"
  integration_http_method = "POST"
}

resource "aws_api_gateway_integration" "request_method_integration_root" {
  for_each = var.functions
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method.request_method_root.http_method
  type = "AWS_PROXY"
  uri = "arn:aws:apigateway:${data.aws_region.default.name}:lambda:path/2015-03-31/functions/${aws_lambda_function.lambda[each.key].arn}/invocations"
  integration_http_method = "POST"
}

resource "aws_api_gateway_method_response" "response_method" {
  for_each = var.functions
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_integration.request_method_integration[each.key].http_method
  status_code = "200"
  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_integration_response" "response_method_integration" {
  for_each = var.functions
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_resource.proxy.id
  http_method = aws_api_gateway_method_response.response_method[each.key].http_method
  status_code = aws_api_gateway_method_response.response_method[each.key].status_code
  response_templates = {
    "application/json" = ""
  }
}


resource "aws_api_gateway_integration_response" "response_method_integration_root" {
  for_each = var.functions
  rest_api_id = aws_api_gateway_rest_api.api.id
  resource_id = aws_api_gateway_rest_api.api.root_resource_id
  http_method = aws_api_gateway_method_response.response_method[each.key].http_method
  status_code = aws_api_gateway_method_response.response_method[each.key].status_code
  response_templates = {
    "application/json" = ""
  }
}

data "aws_iam_policy_document" "lambda" {
  version = "2012-10-17"
  statement {
    principals {
      identifiers = ["lambda.amazonaws.com"]
      type = "Service"
    }
    actions = [
      "sts:AssumeRole"
    ]
  }
}

resource "aws_iam_role" "lambda" {
  for_each = var.functions
  name = join("", concat(["Lambda"], [ for element in split("_", each.key): title(lower(element)) ]))
  description = each.value["description"]
  assume_role_policy = data.aws_iam_policy_document.lambda.json
}

resource "aws_iam_role_policy" "lambda" {
  for_each = var.functions
  policy = each.value["iam_role_policy"]
  role = aws_iam_role.lambda[each.key].id
}

resource "aws_lambda_function" "lambda" {
  for_each = var.functions
  function_name = each.key
  description = each.value["description"]
  filename = each.value["filename"]
  source_code_hash = filesha512(each.value["filename"])
  role = aws_iam_role.lambda[each.key].arn
  handler = each.value["handler"]
  runtime = each.value["runtime"]
  memory_size = each.value["memory_size"]
  timeout = each.value["timeout"]
  vpc_config {
    subnet_ids = each.value["subnet_ids"]
    security_group_ids = each.value["security_group_ids"]
  }
}
