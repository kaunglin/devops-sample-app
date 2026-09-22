# devops-sample-app

Source for the homelab CI/CD demo: a static page that displays the build
version baked into the image, so you can see a deploy land in the browser.

## The loop

```
git push  →  Jenkins builds with Kaniko  →  pushes to the local registry
          →  bumps the image tag in devops-argocd  →  Argo CD syncs
```

## Files

| File | Purpose |
|------|---------|
| `index.html` | The page. `__BUILD_VERSION__` is replaced at build time. |
| `Dockerfile` | nginx:1.27-alpine, takes a `BUILD_VERSION` build arg. |
| `Jenkinsfile` | Declarative pipeline running Kaniko in a Kubernetes agent. |

## Registry addressing

The same registry has two names, which is expected:

| From | Address | Used by |
|------|---------|---------|
| macOS | `localhost:5001` | `docker push`, and image refs in manifests |
| inside the cluster | `homelab-registry:5000` | Kaniko when pushing |

containerd on each node rewrites `localhost:5001` to `homelab-registry:5000`
via `/etc/containerd/certs.d`, so both names resolve to the same blobs.

## Build locally

```bash
docker build --build-arg BUILD_VERSION=$(git rev-parse --short HEAD) -t localhost:5001/sample-app:dev .
docker push localhost:5001/sample-app:dev
```
