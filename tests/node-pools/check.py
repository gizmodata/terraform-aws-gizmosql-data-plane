"""Render the node-pools chart with each test values file and check the manifests' key properties."""
import pathlib
import subprocess
import sys

import yaml

CHART = pathlib.Path(__file__).resolve().parents[2] / "modules" / "node-pools" / "chart"


def render(values: pathlib.Path) -> list[dict]:
    out = subprocess.run(["helm", "template", "test", str(CHART), "-f", str(values)],
                         capture_output=True, text=True, check=True).stdout
    return [d for d in yaml.safe_load_all(out) if d]


def by(docs, kind):
    return {d["metadata"]["name"]: d["spec"] for d in docs if d["kind"] == kind}


def requirement(pool, key):
    return next(r["values"] for r in pool["template"]["spec"]["requirements"] if r["key"] == key)


here = pathlib.Path(__file__).parent

docs = render(here / "by-id-shared-compute.yaml")
classes, pools = by(docs, "EC2NodeClass"), by(docs, "NodePool")
assert set(classes) == {"gizmosql-shared"} and set(pools) == {"gizmosql-shared", "gizmosql-shared-compute"}, docs
assert classes["gizmosql-shared"]["securityGroupSelectorTerms"] == [{"id": "sg-0123456789abcdef0"}]
assert [t["id"] for t in classes["gizmosql-shared"]["subnetSelectorTerms"]] == ["subnet-0aaaaaaaaaaaaaaa1", "subnet-0bbbbbbbbbbbbbbb2"]
assert "max-pods = 110" in classes["gizmosql-shared"]["userData"]
assert pools["gizmosql-shared"]["limits"] == {"cpu": "2048", "memory": "16384Gi"}
shared = pools["gizmosql-shared-compute"]
assert requirement(shared, "karpenter.sh/capacity-type") == ["on-demand"]
assert {"key": "gizmodata.com/compute", "value": "shared", "effect": "NoSchedule"} in shared["template"]["spec"]["taints"]
assert shared["disruption"]["consolidationPolicy"] == "WhenEmpty"

docs = render(here / "by-tag-on-demand.yaml")
classes, pools = by(docs, "EC2NodeClass"), by(docs, "NodePool")
assert set(pools) == {"gizmosql-team-a", "gizmosql-team-b"}, list(pools)
for name in classes:
    assert classes[name]["securityGroupSelectorTerms"] == [{"tags": {"karpenter.sh/discovery": "example-eks"}}]
    assert classes[name]["subnetSelectorTerms"] == [{"tags": {"karpenter.sh/discovery": "example-eks"}}]
    assert "userData" not in classes[name]
assert requirement(pools["gizmosql-team-a"], "karpenter.sh/capacity-type") == ["on-demand"]
assert requirement(pools["gizmosql-team-b"], "node.kubernetes.io/instance-type") == ["r8gd.xlarge", "r8gd.2xlarge"]
for name, pool in pools.items():
    tenant = name.removeprefix("gizmosql-")
    assert {"key": "gizmodata.com/tenant", "value": tenant, "effect": "NoSchedule"} in pool["template"]["spec"]["taints"]
    assert pool["template"]["spec"]["startupTaints"] == [{"key": "ebs.csi.aws.com/agent-not-ready", "effect": "NoExecute"}]

# Both Bottlerocket volumes are listed (listing any replaces Karpenter's defaults) and both are
# encrypted with the tenant's key, under the CRD's field name `kmsKeyID`.
for values in ("by-id-shared-compute.yaml", "by-tag-on-demand.yaml"):
    config = yaml.safe_load(open(here / values))
    for name, spec in by(render(here / values), "EC2NodeClass").items():
        key = config["tenants"][name.removeprefix("gizmosql-")]["kmsKeyArn"]
        volumes = {m["deviceName"]: m["ebs"] for m in spec["blockDeviceMappings"]}
        assert set(volumes) == {"/dev/xvda", "/dev/xvdb"}, volumes
        for device, ebs in volumes.items():
            assert ebs["encrypted"] is True and ebs["kmsKeyID"] == key, (name, device, ebs)
            assert "kmsKeyId" not in ebs, "kmsKeyId is pruned by the API server; the field is kmsKeyID"
        assert volumes["/dev/xvda"]["volumeSize"] == "4Gi" and volumes["/dev/xvdb"]["volumeSize"] == "100Gi"

print("node-pools chart checks passed")
sys.exit(0)
