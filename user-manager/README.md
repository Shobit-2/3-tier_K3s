# User Manager — K8s 3-Tier App

## Structure
```
user-manager/
├── backend/          # Node + Express API
├── frontend/         # React + Nginx
└── k8s/
    ├── namespaces/
    ├── db/           # PostgreSQL StatefulSet
    ├── backend/      # Backend Deployment
    └── frontend/     # Frontend Deployment
```

---

## 1. Build & Push Images

```bash
# Backend
cd backend
docker build -t <DOCKERHUB_USER>/user-manager-backend:latest .
docker push <DOCKERHUB_USER>/user-manager-backend:latest

# Frontend
cd ../frontend
docker build -t <DOCKERHUB_USER>/user-manager-frontend:latest .
docker push <DOCKERHUB_USER>/user-manager-frontend:latest
```

---

## 2. Update Image References

In `k8s/backend/backend.yaml` and `k8s/frontend/frontend.yaml`, replace:
```
YOUR_DOCKERHUB_USERNAME/user-manager-backend:latest
YOUR_DOCKERHUB_USERNAME/user-manager-frontend:latest
```
with your actual DockerHub username.

---

## 3. Deploy to Cluster (in order)

```bash
# 1. Namespaces first
kubectl apply -f k8s/namespaces/namespaces.yaml

# 2. Database
kubectl apply -f k8s/db/postgres.yaml

# Wait for postgres to be ready
kubectl rollout status statefulset/postgres -n db

# 3. Backend
kubectl apply -f k8s/backend/backend.yaml

# Wait for backend
kubectl rollout status deployment/backend -n backend

# 4. Frontend
kubectl apply -f k8s/frontend/frontend.yaml
```

---

## 4. Access the App

```bash
# Get any worker node's public IP from AWS console, then:
http://<WORKER_NODE_PUBLIC_IP>:30080
```

Make sure port 30080 is open in your AWS Security Group for the worker nodes.

---

## 5. Verify

```bash
kubectl get all -n db
kubectl get all -n backend
kubectl get all -n frontend

kubectl logs -n backend deployment/backend
kubectl logs -n db statefulset/postgres
```

---

## Notes

- **PVC**: k3s ships with a local-path provisioner — PVC will auto-bind. For EKS migration, uncomment `storageClassName: gp2` in `k8s/db/postgres.yaml`.
- **DB password**: change `StrongPass@2024` in `k8s/db/postgres.yaml` and `k8s/backend/backend.yaml` to the same value before deploying.
- **Frontend → Backend**: nginx proxies `/api/*` to `backend-service.backend.svc.cluster.local:5000` via cross-namespace DNS — no extra config needed.
- **Scaling**: `kubectl scale deployment backend -n backend --replicas=4`
- **EKS migration**: only change needed is `storageClassName` in the PVC and swap NodePort for a LoadBalancer service or ALB Ingress.
