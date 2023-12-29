// goal: clean up into modules at some point 

resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
}

resource "aws_subnet" "main" {
  vpc_id     = aws_vpc.main.id
  cidr_block = cidrsubnet(aws_vpc.main.cidr_block, 4, 4)
}

resource "aws_route_table" "main" {
  vpc_id = aws_vpc.main.id
}

resource "aws_route_table_association" "rt_association" {
  route_table_id = aws_route_table.main.id
  subnet_id      = aws_subnet.main.id
}

resource "aws_s3_bucket" "s3_bucket" {
  bucket_prefix = "geo-tf-"
}

resource "aws_lambda_function" "lambda" {
  function_name = "csv-processor"
  role          = aws_iam_role.lambda_assume_role.arn
  handler       = "lambda_handler.py"
  runtime       = "python3.12"
  filename      = "./lambda_code.zip"
}

resource "aws_iam_role_policy_attachment" "lambda_role_attachment" {
  role       = aws_iam_role.lambda_assume_role.name
  policy_arn = aws_iam_policy.lambda_log_policy.arn
}

resource "aws_iam_role" "lambda_assume_role" {
  name = "lambda-execution-role"
  assume_role_policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Principal : {
          Service : "lambda.amazonaws.com"
        },
        Action : "sts:AssumeRole"
      }
    ]
  })
}

// TODO: make more restrictive! 
resource "aws_iam_policy" "lambda_log_policy" {
  name = "lambda-log-policy"
  policy = jsonencode({
    Version : "2012-10-17",
    Statement : [
      {
        Effect : "Allow",
        Action : "logs:CreateLogGroup",
        Resource : "*"
      },
      {
        Effect : "Allow",
        Action : [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ],
        Resource : [
          "*"
        ]
      }
    ]
  })
}

resource "aws_s3_bucket_notification" "put_csv_bucket" {
  bucket = aws_s3_bucket.s3_bucket.id 
  lambda_function {
    lambda_function_arn = aws_lambda_function.lambda.arn 
    events = [ "s3:ObjectCreated:*", "s3:ObjectRemoved:*" ]
  }
}

resource "aws_lambda_permission" "lambda_s3_invoke" {
  statement_id = "AllowS3Invoke"
  action = "lambda:InvokeFunction"
  function_name = aws_lambda_function.lambda.function_name 
  principal = "s3.amazonaws.com" 
  source_arn = "arn:aws:s3:::${aws_s3_bucket.s3_bucket.id}"
}
