# terraform-aws-gizmosql-data-plane

Terraform modules for running [GizmoSQL](https://github.com/gizmodata/gizmosql) clusters on Amazon EKS
with [Karpenter](https://karpenter.sh). They are the shared building blocks of every GizmoData
data plane on AWS, whether GizmoData runs it or it runs in a customer's own account.

| Module | What it manages |
| --- | --- |
| [`modules/node-pools`](modules/node-pools) | A tainted Karpenter `EC2NodeClass` + `NodePool` per tenant, and an optional bin-packed pool for small shared clusters |

## node-pools

Each tenant gets `gizmosql-<tenant>`: nodes labelled and tainted `gizmodata.com/tenant=<tenant>`,
arm64, with the instance store striped as RAID0 for the NVMe cache. The GizmoData control plane
schedules a cluster onto a tenant through its node scheduling profile (the label + toleration), and
pins it to the instance type of its compute size, so **`instance_types` must include every size
the control plane offers that tenant**.

One shared tenant gives every workload a place to run. A tenant per customer isolates them
(separate nodes, and a separate KMS key / IAM role per tenant in the calling stack):

```hcl
module "gizmosql_node_pools" {
  source = "git::https://github.com/gizmodata/terraform-aws-gizmosql-data-plane.git//modules/node-pools?ref=v0.1.0"

  cluster_name           = module.eks.cluster_name
  node_role_name         = module.karpenter.node_iam_role_name
  node_security_group_id = module.eks.node_security_group_id
  subnet_ids             = module.vpc.private_subnets
  ami_alias              = "bottlerocket@v1.64.0"
  tags                   = local.tags

  tenants = {
    shared = {
      instance_types = ["r8gd.large", "r8gd.xlarge", "r8gd.2xlarge", "r8gd.4xlarge"]
      kms_key_arn    = aws_kms_key.tenant["shared"].arn
      cpu_limit      = "512"
      memory_limit   = "4096Gi"
    }
    team-a = {
      instance_types = ["r8gd.xlarge", "r8gd.2xlarge"]
      kms_key_arn    = aws_kms_key.tenant["team-a"].arn
      capacity_types = ["on-demand"]
    }
  }

  # Optional: small clusters (pico / nano / micro) bin-packed on shared nodes.
  shared_compute = {
    tenant         = "shared"
    instance_types = ["r8gd.xlarge", "r8gd.2xlarge"]
  }

  depends_on = [helm_release.karpenter]
}
```

The pools are rendered by a small local Helm chart (no `kubernetes_manifest`, so a plan never
needs the cluster's API or Karpenter's CRDs), so the calling stack needs a configured `helm`
provider (2.17+ or 3.x) and Karpenter v1 already installed.

### Moving an existing stack onto the module

If the stack already renders these pools with its own `karpenter-node-config` chart, keep the
release name and add a `moved` block; the plan should then show only the chart path changing:

```hcl
moved {
  from = helm_release.karpenter_node_config
  to   = module.gizmosql_node_pools.helm_release.this
}
```

### Selecting the node security group

Pass `node_security_group_id` whenever the stack owns the cluster. Without it the pools select
security groups by the `karpenter.sh/discovery` tag, and a leftover node security group that kept
that tag gets attached too; the AWS Load Balancer Controller then refuses to register the nodes
in NLB target groups ("expected exactly one securityGroup tagged with kubernetes.io/cluster/…").

## Versioning

Releases are tagged `vX.Y.Z` and listed in [CHANGELOG.md](CHANGELOG.md). Pin `?ref=` to a tag.

## License

Apache License 2.0. See [LICENSE](LICENSE).
