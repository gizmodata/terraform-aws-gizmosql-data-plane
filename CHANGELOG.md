# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [v0.2.0] - 2026-10-07

### Fixed
- **Node volumes are encrypted with the tenant's KMS key.** The EC2NodeClass set `kmsKeyId`, but
  the Karpenter v1 field is `kmsKeyID`, so the API server pruned it and the root volume used the
  account's default EBS key. Listing `blockDeviceMappings` also replaces Karpenter's Bottlerocket
  defaults, so the data volume `/dev/xvdb` came from the AMI snapshot **unencrypted**. Both
  volumes are now listed, encrypted with `kmsKeyID` = the tenant key: `/dev/xvda` (OS,
  `os_volume_size`, default 4Gi; it was 100Gi, almost all unused) and `/dev/xvdb` (data,
  `data_volume_size`, default 100Gi; it was the AMI's 20 GB).

### Added
- An inline policy on the Karpenter controller role letting it use the tenant keys for the
  nodes' volumes (`kms:CreateGrant` for AWS resources, encrypt / decrypt / data keys); without
  it every launch with an encrypted volume fails. The node classes are applied only after the
  policy (plus 30 s for IAM to propagate), so no launch ever sees the key without the permission.

### Changed
- **Breaking:** new required input `karpenter_controller_role_name`; the module now also needs
  the `aws` and `time` providers. `ami_alias` must be a Bottlerocket alias.
- Existing nodes are marked drifted and replaced by Karpenter as its disruption rules allow;
  nodes running pods annotated `karpenter.sh/do-not-disrupt` keep their old volumes until
  those pods move.

## [v0.1.0] - 2026-10-07

### Added
- `modules/node-pools`: per-tenant Karpenter `EC2NodeClass` + `NodePool` for GizmoSQL workloads
  (tenant label + taint, RAID0 instance store, EBS CSI startup taint, consolidation), plus an
  optional bin-packed shared-compute pool. Node security group and subnets are selected by id or
  by the `karpenter.sh/discovery` tag; capacity types and CPU / memory limits are per tenant.
  Renders exactly what the per-deployment `karpenter-node-config` charts it replaces render, so
  adopting it is a no-op for the cluster.

### Known issues
- The root volume's `kmsKeyId` is pruned by the API server (the Karpenter v1 field is
  `kmsKeyID`), and Bottlerocket's data volume (`/dev/xvdb`) falls back to the AMI's unencrypted
  mapping. To be fixed in 0.2.0.
