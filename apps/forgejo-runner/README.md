# forgejo-runner

Forgejo Actions runner for the instance in [`../forgejo`](../forgejo).

## Why the chart is vendored

Upstream is `forgejo-helm/forgejo-runner`, but it cannot be consumed the usual
way:

- **Not on OCI.** `helm pull oci://code.forgejo.org/forgejo-helm/forgejo-runner:0.7.5`
  fails with `not found`, despite the chart's own README telling you to run
  exactly that.
- **No `index.yaml` and no git tags**, so it is not usable as a Helm git repo
  either. Both kustomize's `helmCharts` and ArgoCD's `spec.source.helm` need
  one of those two forms.

So `chart/` acts as a local chart repo: it holds a verbatim copy of upstream at
`chart/forgejo-runner/`, and `kustomization.yaml` points kustomize at it via
`helmGlobals.chartHome: "chart"` (kustomize resolves a local chart as
`chartHome/<name>`). `repo` is omitted entirely.

Verify a change locally with:

```bash
cd apps/forgejo-runner
kubectl kustomize --enable-helm .
```

`--enable-helm` is only needed for the standalone `kubectl kustomize` binary;
ArgoCD's built-in kustomize has Helm enabled already.

| | |
|---|---|
| Chart | `forgejo-runner` 0.7.5 |
| Upstream | <https://code.forgejo.org/forgejo-helm/forgejo-runner> |
| Vendored at | `3ae5398156088d703afb5aefc1d6f38574ab30a6` (2026-05-25) |

### Refreshing the vendored chart

```bash
cd "$(mktemp -d)"
git clone https://code.forgejo.org/forgejo-helm/forgejo-runner.git
cd forgejo-runner
git log -1 --format=%H            # update the commit above

D=~/homelab/v34l/git-k8s/apps/forgejo-runner/chart/forgejo-runner
cp Chart.yaml LICENSE README.md README.md.gotmpl values.yaml values-dind-bypass.yaml "$D/"
cp -r templates "$D/"
```

Then bump `version:` in both `chart/forgejo-runner/Chart.yaml` and
`kustomization.yaml`. kustomize does not enforce the version for local charts,
so treat a mismatch as a sign the chart was re-vendored without the bump.

## Why registration is manual

The chart can register the runner itself (`runner.config.create: true`), but
it does so with a `helm.sh/hook: pre-install` Job that `kubectl patch`es a
Secret. ArgoCD does not run Helm hooks, and `selfHeal: true` would revert that
patch on every sync, leaving the app permanently OutOfSync.

So `runner.config.create` is `false`: the chart renders no hooks at all and
just references a pre-existing secret. Everything stays declarative.

## One-time setup

1. Create the runner registration in Forgejo at
   <https://git.m15ty.com/admin/actions/runners> (instance-wide; use
   `/user/settings/actions/runners` or `/org/{org}/settings/actions/runners`
   to scope it more narrowly). Copy the **UUID** and **Token**.

   Alternative without touching the UI — on the Forgejo host:

   ```bash
   # openssl rand -hex 20
   forgejo forgejo-cli actions register --name runner1 \
     --secret 7c31591e8b67225a116d4a4519ea8e507e08f71f
   ```

   The first 16 hex chars are the UUID and the remaining 24 are the token.

2. Write the registration to the gitignored secret:

   ```bash
   cd apps/forgejo-runner
   cp runner-secret.yaml.example runner-secret.yaml
   $EDITOR runner-secret.yaml      # fill in uuid and token
   ```

3. Create it before (or right after) the first ArgoCD sync:

   ```bash
   kubectl create namespace forgejo-runner
   kubectl apply -f runner-secret.yaml
   ```

   The Deployment's init container copies `.runner` out of this secret, so it
   stays in `CreateContainerConfigError` until the secret exists.

4. Verify the runner shows up online:

   ```bash
   kubectl -n forgejo-runner get pods
   ```

## Labels and `runs-on`

Labels are fixed at registration time and live in `.runner`, not in
`helm/values.yaml`. The chart default `labels: []` is only a fallback for
`daemon` when `.runner` has none.

For the in-pod dind sidecar, register with something like:

```
--labels "docker:docker://node:lts,ubuntu-latest:docker://node:lts,ubuntu-22.04:docker://node:lts"
```

Then `runs-on: docker` in a workflow resolves to the runner.

## Capacity

`runner.config.file.runner.capacity: 1` means one job at a time per pod. Raise
it, or `replicaCount`, for parallel jobs. Note the dind sidecar is
`privileged: true` and has no resource limits by default — see below.

## Known sharp edges

- **Privileged workload.** `templates/deployment.yaml` hardcodes a `dind`
  sidecar with no values toggle, so `securityContext.privileged: true` is
  mandatory for docker-in-docker. Only the job containers are unprivileged
  (`runner.config.file.container.privileged: false`). This is a privileged
  pod on Talos running code from your CI.
- **One runner identity per secret.** To scale past one runner you need a
  second registration and a second secret; `existingSecret` is a single name.
- **No git tag upstream**, so pinning is by vendored commit only.
- `system/secrets/VaultSecretProvider.yaml` in this repo is broken (stray
  quote in `objectName`, and it targets namespace `default`), so there is no
  working secret backend to pull the registration from. Hence the local,
  gitignored file.