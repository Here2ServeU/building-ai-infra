terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = ">= 5.40" }
    tls = { source = "hashicorp/tls", version = ">= 4.0" }
  }
}

data "aws_caller_identity" "current" {}

resource "aws_iam_role" "cluster" {
  name = "${var.cluster_name}-cluster"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "cluster_policy" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy",
    "arn:aws:iam::aws:policy/AmazonEKSVPCResourceController",
  ])
  role       = aws_iam_role.cluster.name
  policy_arn = each.value
}

resource "aws_kms_key" "secrets" {
  description             = "EKS secrets envelope encryption for ${var.cluster_name}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = var.tags
}

resource "aws_eks_cluster" "this" {
  name     = var.cluster_name
  role_arn = aws_iam_role.cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.subnet_ids
    endpoint_private_access = true
    endpoint_public_access  = var.endpoint_public_access
    public_access_cidrs     = var.public_access_cidrs
  }

  encryption_config {
    provider { key_arn = aws_kms_key.secrets.arn }
    resources = ["secrets"]
  }

  enabled_cluster_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  access_config {
    authentication_mode = "API_AND_CONFIG_MAP"
  }

  tags = var.tags

  depends_on = [aws_iam_role_policy_attachment.cluster_policy]
}

# OIDC provider for IRSA
data "tls_certificate" "oidc" {
  url = aws_eks_cluster.this.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "this" {
  url             = aws_eks_cluster.this.identity[0].oidc[0].issuer
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.oidc.certificates[0].sha1_fingerprint]
  tags            = var.tags
}

# Node group IAM role
resource "aws_iam_role" "node" {
  name = "${var.cluster_name}-node"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node" {
  for_each = toset([
    "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy",
    "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy",
    "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly",
    "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore",
  ])
  role       = aws_iam_role.node.name
  policy_arn = each.value
}

resource "aws_eks_node_group" "system" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "system"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = ["m6i.large"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 4
  }

  update_config { max_unavailable = 1 }

  labels = { workload = "system" }

  taint {
    key    = "workload"
    value  = "system"
    effect = "NO_SCHEDULE"
  }

  tags = merge(var.tags, { "k8s.io/cluster-autoscaler/enabled" = "true" })
}

resource "aws_eks_node_group" "apps" {
  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "apps"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  instance_types  = var.app_node_instance_types

  scaling_config {
    desired_size = var.app_node_desired
    min_size     = var.app_node_min
    max_size     = var.app_node_max
  }

  update_config { max_unavailable_percentage = 25 }

  labels = { workload = "apps" }

  tags = merge(var.tags, { "k8s.io/cluster-autoscaler/enabled" = "true" })
}

# -----------------------------------------------------------------------------
# GPU node group (Building AI Infrastructure, Part 3)
# Off by default. Starts at 0 nodes; the cluster autoscaler adds a node only
# when a pod requests nvidia.com/gpu, and removes it after the scale-down delay.
# The taint keeps non-GPU work off these (expensive) nodes.
# The EKS NVIDIA AMI ships the driver, so the GPU Operator runs with
# driver.enabled=false (see flux/infrastructure/gpu/).
# -----------------------------------------------------------------------------
resource "aws_eks_node_group" "gpu" {
  count = var.gpu_enabled ? 1 : 0

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "gpu"
  node_role_arn   = aws_iam_role.node.arn
  subnet_ids      = var.subnet_ids
  ami_type        = "AL2023_x86_64_NVIDIA"
  instance_types  = var.gpu_node_instance_types

  scaling_config {
    desired_size = 0
    min_size     = 0
    max_size     = var.gpu_node_max
  }

  update_config { max_unavailable = 1 }

  labels = {
    workload                 = "gpu"
    "nvidia.com/gpu.present" = "true"
  }

  taint {
    key    = "nvidia.com/gpu"
    value  = "present"
    effect = "NO_SCHEDULE"
  }

  # Cluster autoscaler >= 1.24 reads managed node group labels/taints from the
  # EKS API to scale from zero; these tags are the fallback hint.
  tags = merge(var.tags, {
    "k8s.io/cluster-autoscaler/enabled"                                = "true"
    "k8s.io/cluster-autoscaler/node-template/label/workload"           = "gpu"
    "k8s.io/cluster-autoscaler/node-template/taint/nvidia.com/gpu"     = "present:NoSchedule"
    "k8s.io/cluster-autoscaler/node-template/resources/nvidia.com/gpu" = "1"
  })

  lifecycle {
    ignore_changes = [scaling_config[0].desired_size]
  }
}
