output "node_pool_names" {
  description = "The Karpenter NodePools this module manages."
  value = concat(
    [for key in keys(var.tenants) : "gizmosql-${key}"],
    var.shared_compute == null ? [] : ["gizmosql-shared-compute"],
  )
}

output "instance_types_by_tenant" {
  description = "Instance types each tenant's NodePool may launch (compare with the compute sizes the control plane offers)."
  value       = { for key, cfg in var.tenants : key => cfg.instance_types }
}
