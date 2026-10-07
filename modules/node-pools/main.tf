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
