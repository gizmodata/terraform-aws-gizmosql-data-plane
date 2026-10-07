# Changelog

All notable changes to this project are documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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
