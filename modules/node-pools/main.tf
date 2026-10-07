# The NodePools / EC2NodeClasses are rendered by a local Helm chart rather than
# kubernetes_manifest, which needs the cluster's API (and Karpenter's CRDs) at plan time.
resource "helm_release" "this" {
  name      = var.release_name
  chart     = "${path.module}/chart"
  namespace = var.namespace

  values = [
    yamlencode({
      clusterName         = var.cluster_name
      nodeRoleName        = var.node_role_name
      nodeSecurityGroupId = var.node_security_group_id
      subnetIds           = var.subnet_ids
      tags                = var.tags
      amiAlias            = var.ami_alias
      userData            = var.user_data
      osVolumeSize        = var.os_volume_size
      dataVolumeSize      = var.data_volume_size
      tenants = {
        for key, cfg in var.tenants : key => {
          instanceTypes = cfg.instance_types
          kmsKeyArn     = cfg.kms_key_arn
          capacityTypes = cfg.capacity_types
          cpuLimit      = cfg.cpu_limit
          memoryLimit   = cfg.memory_limit
        }
      }
      sharedCompute = var.shared_compute == null ? null : {
        tenant        = var.shared_compute.tenant
        instanceTypes = var.shared_compute.instance_types
        cpuLimit      = var.shared_compute.cpu_limit
        memoryLimit   = var.shared_compute.memory_limit
      }
    })
  ]
}

# Karpenter launches the nodes (EC2 CreateFleet) with its controller role, so that role must be
# able to use each tenant's key for the encrypted volumes; without it every launch fails. The
# keys' policies are expected to delegate to IAM (the usual account-root statement).
data "aws_iam_policy_document" "karpenter_tenant_kms" {
  statement {
    sid = "UseTenantKeysForNodeVolumes"
    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*",
      "kms:DescribeKey",
    ]
    resources = distinct([for cfg in values(var.tenants) : cfg.kms_key_arn])
  }
  statement {
    sid       = "GrantTenantKeysToEC2"
    actions   = ["kms:CreateGrant"]
    resources = distinct([for cfg in values(var.tenants) : cfg.kms_key_arn])
    condition {
      test     = "Bool"
      variable = "kms:GrantIsForAWSResource"
      values   = ["true"]
    }
  }
}

resource "aws_iam_role_policy" "karpenter_tenant_kms" {
  name   = "${var.release_name}-tenant-kms"
  role   = var.karpenter_controller_role_name
  policy = data.aws_iam_policy_document.karpenter_tenant_kms.json
}
