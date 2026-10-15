data "aws_iam_policy_document" "api_pod_assume_role" {
  statement {
    effect = "Allow"

    actions = [
      "sts:AssumeRole",
      "sts:TagSession",
    ]

    principals {
      type        = "Service"
      identifiers = ["pods.eks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "api_pod" {
  name               = "${local.cluster_name}-api-pod-role"
  assume_role_policy = data.aws_iam_policy_document.api_pod_assume_role.json
}

data "aws_iam_policy_document" "api_pod" {
  statement {
    sid       = "ReadRDSCredentials"
    effect    = "Allow"
    actions   = ["secretsmanager:GetSecretValue"]
    resources = [var.api_rds_secret_arn]
  }

  statement {
    sid       = "PublishTicketRequests"
    effect    = "Allow"
    actions   = ["sqs:SendMessage"]
    resources = [var.api_queue_arn]
  }
}

resource "aws_iam_role_policy" "api_pod" {
  name   = "${local.cluster_name}-api-pod-policy"
  role   = aws_iam_role.api_pod.id
  policy = data.aws_iam_policy_document.api_pod.json
}

resource "aws_eks_pod_identity_association" "api" {
  cluster_name    = aws_eks_cluster.this.name
  namespace       = var.api_namespace
  service_account = var.api_service_account_name
  role_arn        = aws_iam_role.api_pod.arn
}