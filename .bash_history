ls
sudo systemctl status k3s --no-pager
kubectl get nodes
kubectl get namespace
kubectl get pods
kubectl get nodes
kubectl get nodes -o wide
kubectl get pods -A
kubectl get storageclass
kubectl cluster-info
ls
kubectl get nodes
kubectl get pods
kubectl get pods -A
mkdir -p ~/k3s-manifests/{00-namespaces,01-secrets,02-configmaps,03-database,04-backend,05-frontend}
cd ~/k3s-manifests
ls
cat > 00-namespaces/namespaces.yaml << 'EOF'
apiVersion: v1
kind: Namespace
metadata:
  name: frontend
  labels:
    app: 3tier
---
apiVersion: v1
kind: Namespace
metadata:
  name: backend
  labels:
    app: 3tier
---
apiVersion: v1
kind: Namespace
metadata:
  name: db
  labels:
    app: 3tier
EOF

ls
cd 00-namespaces/
ls
cat namespaces.yaml 
cd ..
ls
kubectl apply -f 00-namespaces/namespaces.yaml
kubectl get namespaces | grep -E "frontend|backend|db"
# Generate base64 values
echo -n "appuser"        | base64   # POSTGRES_USER
echo -n "apppassword123" | base64   # POSTGRES_PASSWORD
echo -n "appdb"          | base64   # POSTGRES_DB
cat > 01-secrets/db-secret.yaml << 'EOF'
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: db
type: Opaque
data:
  POSTGRES_USER: YXBwdXNlcg==
  POSTGRES_PASSWORD: YXBwcGFzc3dvcmQxMjM=
  POSTGRES_DB: YXBwZGI=
---
apiVersion: v1
kind: Secret
metadata:
  name: db-secret
  namespace: backend
type: Opaque
data:
  DB_PASSWORD: YXBwcGFzc3dvcmQxMjM=
EOF

kubectl apply -f 01-secrets/db-secret.yaml
kubectl get secrets -n db
kubectl get secrets -n backend
# Get worker 1 public IP
curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null ||   kubectl get nodes -o wide | grep -v master | head -1 | awk '{print $7}'
# Backend ConfigMap
cat > 02-configmaps/backend-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: backend-config
  namespace: backend
data:
  BACKEND_PORT: "5000"
  DB_HOST: "postgres-service.db.svc.cluster.local"
  DB_PORT: "5432"
  DB_NAME: "appdb"
  DB_USER: "appuser"
  NODE_ENV: "production"
EOF

curl -s http://169.254.169.254/latest/meta-data/public-ipv4 2>/dev/null ||   kubectl get nodes -o wide | grep -v master | head -1 | awk '{print $7}'
# Frontend ConfigMap — replace WORKER1_PUBLIC_IP with real IP
cat > 02-configmaps/frontend-config.yaml << 'EOF'
apiVersion: v1
kind: ConfigMap
metadata:
  name: frontend-config
  namespace: frontend
data:
  BACKEND_URL: "http://98.92.140.178:31000"
EOF

kubectl apply -f 02-configmaps/backend-config.yaml
kubectl apply -f 02-configmaps/frontend-config.yaml
kubectl get configmap -n backend
kubectl get configmap -n frontend
cat > 03-database/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: postgres-service
  namespace: db
spec:
  selector:
    app: postgres
  clusterIP: None
  ports:
  - port: 5432
    targetPort: 5432
    protocol: TCP
EOF

cat > 03-database/statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: db
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 1Gi
EOF

cd 03-database/
ls
nano cat > 03-database/statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: db
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 1Gi
EOF

ls
rm cat > 03-database/statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: db
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 1Gi
EOF

ls
pwd
ls
rm -rf statefulset.yaml 
ls
nano cat > 03-database/statefulset.yaml << 'EOF'
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: postgres
  namespace: db
spec:
  serviceName: postgres-service
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:15-alpine
        ports:
        - containerPort: 5432
        env:
        - name: POSTGRES_USER
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_USER
        - name: POSTGRES_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_PASSWORD
        - name: POSTGRES_DB
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: POSTGRES_DB
        - name: PGDATA
          value: /var/lib/postgresql/data/pgdata
        volumeMounts:
        - name: postgres-storage
          mountPath: /var/lib/postgresql/data
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 30
          periodSeconds: 10
          failureThreshold: 3
        readinessProbe:
          exec:
            command:
            - pg_isready
            - -U
            - appuser
            - -d
            - appdb
          initialDelaySeconds: 10
          periodSeconds: 5
          failureThreshold: 3
  volumeClaimTemplates:
  - metadata:
      name: postgres-storage
    spec:
      accessModes: ["ReadWriteOnce"]
      storageClassName: local-path
      resources:
        requests:
          storage: 1Gi
EOF

ls
vi statefulset.yaml
lx
ls
cat service.yaml 
ls
rm -rf statefulset.yaml 
ls
vi statefulset.yaml
cat s
cat statefulset.yaml 
cd ..
ls
kubectl apply -f 03-database/service.yaml
kubectl apply -f 03-database/statefulset.yaml
kubectl get pods -n db -w
kubectl get pods -n db 
kubectl get statefulset -n db
kubectl get pvc -n db
# Create the users table inside PostgreSQL
kubectl exec -it postgres-0 -n db --   psql -U appuser -d appdb -c "
    CREATE TABLE IF NOT EXISTS users (
      id         SERIAL PRIMARY KEY,
      name       VARCHAR(100) NOT NULL,
      email      VARCHAR(255) NOT NULL UNIQUE,
      created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );
    INSERT INTO users (name, email) VALUES
      ('Alice Johnson', 'alice@example.com'),
      ('Bob Smith',     'bob@example.com'),
      ('Carol White',   'carol@example.com');
    SELECT * FROM users;
  "
cat > 04-backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shobitk/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: BACKEND_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: BACKEND_PORT
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD
        - name: DATABASE_URL
          value: "postgresql://appuser:$(DB_PASSWORD)@postgres-service.db.svc.cluster.local:5432/appdb"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 40
          periodSeconds: 30
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 40
          periodSeconds: 10
          failureThreshold: 3
EOF

cat > 04-backend/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: backend-service
  namespace: backend
spec:
  selector:
    app: backend
  type: NodePort
  ports:
  - port: 5000
    targetPort: 5000
    nodePort: 31000
    protocol: TCP
EOF

cat 04-backend/deployment.yaml 
ls
kubectl apply -f 04-backend/deployment.yaml
kubectl apply -f 04-backend/service.yaml
kubectl get pods -n backend -w
kubectl get pods -n backend 
# Test from inside the cluster
kubectl exec -it postgres-0 -n db --   wget -qO- http://backend-service.backend.svc.cluster.local:5000/health/live
kubectl get pods -n backend 
kubectl get pods -n backend -w
s
ls
kubectl get pods -n backend -w
kubectl get pods -n backend 
# Get exact pod name
POD=$(kubectl get pods -n backend -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $POD"
# Read logs
kubectl logs $POD -n backend
ls
cd k3s-manifests/
cd 04-backend/
ls
rm -rf deployment.yaml 
cd ..
cat > ~/k3s-manifests/04-backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shobitk/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: BACKEND_PORT
          value: "5000"
        - name: DATABASE_URL
          value: "postgresql://appuser:apppassword123@postgres-service.db.svc.cluster.local:5432/appdb"
        - name: NODE_ENV
          value: "production"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 5
EOF

cat 04-backend/deployment.yaml 
cd 04-backend/
ls
rm -rf deployment.yaml 
cd .
cd ..
cat > ~/k3s-manifests/04-backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shobitk/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: BACKEND_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: BACKEND_PORT
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: NODE_ENV
        - name: PGHOST
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_HOST
        - name: PGPORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_PORT
        - name: PGDATABASE
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_NAME
        - name: PGUSER
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: DB_USER
        - name: PGPASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DB_PASSWORD
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 5
EOF

ls
cat 04-backend/deployment.yaml 
ls
# From master node — check the running container's env
POD=$(kubectl get pods -n backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
kubectl exec $POD -n backend -- env | grep -E "PG|DATABASE" 2>/dev/null || echo "No backend pods running yet"
kubectl get pods -n backend
# Generate base64 for the full DATABASE_URL
echo -n "postgresql://appuser:apppassword123@postgres-service.db.svc.cluster.local:5432/appdb" | base64
nano ~/k3s-manifests/01-secrets/db-secret.yaml
kubectl apply -f ~/k3s-manifests/01-secrets/db-secret.yaml
cat ~/k3s-manifests/01-secrets/db-secret.yaml
kubectl apply -f ~/k3s-manifests/01-secrets/db-secret.yaml
cat > ~/k3s-manifests/04-backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shobitk/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: BACKEND_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: BACKEND_PORT
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: NODE_ENV
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DATABASE_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        livenessProbe:
          httpGet:
            path: /health/live
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health/ready
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 5
EOF

kubectl apply -f 01-secrets/db-secret.yaml
kubectl apply -f 04-backend/deployment.yaml
kubectl rollout restart deployment/backend -n backend
kubectl rollout status deployment/backend -n backend -w
kubectl rollout status deployment/backend -n backend 
kubectl get pods -n backend
# Check logs of the newest pod
POD=$(kubectl get pods -n backend --sort-by='.metadata.creationTimestamp' -o jsonpath='{.items[-1].metadata.name}')
echo "Newest pod: $POD"
echo ""
echo "=== CURRENT LOGS ==="
kubectl logs $POD -n backend
echo ""
echo "=== PREVIOUS LOGS ==="
kubectl logs $POD -n backend --previous 2>/dev/null || echo "No previous logs yet"
echo ""
echo "=== DESCRIBE ==="
kubectl describe pod $POD -n backend | tail -40
# Check what health routes actually exist
POD=$(kubectl get pods -n backend --sort-by='.metadata.creationTimestamp' -o jsonpath='{.items[-1].metadata.name}')
# Test each endpoint
kubectl exec -it postgres-0 -n db -- wget -qO- --server-response   http://backend-service.backend.svc.cluster.local:5000/health 2>&1 | head -5
kubectl exec -it postgres-0 -n db -- wget -qO- --server-response   http://backend-service.backend.svc.cluster.local:5000/health/live 2>&1 | head -5
kubectl exec -it postgres-0 -n db -- wget -qO- --server-response   http://backend-service.backend.svc.cluster.local:5000/health/ready 2>&1 | head -5
kubectl delete deployment backend -n backend
kubectl get pods -n backend
cat > ~/k3s-manifests/04-backend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: backend
  namespace: backend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: backend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: backend
    spec:
      containers:
      - name: backend
        image: shobitk/backend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
        env:
        - name: BACKEND_PORT
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: BACKEND_PORT
        - name: NODE_ENV
          valueFrom:
            configMapKeyRef:
              name: backend-config
              key: NODE_ENV
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: DATABASE_URL
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "300m"
        livenessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /health
            port: 5000
          initialDelaySeconds: 60
          periodSeconds: 15
          timeoutSeconds: 10
          failureThreshold: 5
EOF

kubectl get pods -n backend
kubectl apply -f ~/k3s-manifests/04-backend/deployment.yaml
kubectl get pods -n backend -w
kubectl get pods -n backend 
cat 04-backend/deployment.yaml 
kubectl get pods -n backend 
Both Backend Pods Running! 🎉
NAME                      READY   STATUS    RESTARTS   AGE
backend-586799f5c-nl6hs   1/1     Running   0          73s  ✅
backend-586799f5c-tlv6c   1/1     Running   0          73s  ✅
READY: 1/1   → probe passing ✅
RESTARTS: 0  → no crashes ✅
STATUS: Running → healthy ✅
📍 Quick Verification Before Frontend
bash# Test backend API from inside cluster
kubectl exec -it postgres-0 -n db --   wget -qO- http://backend-service.backend.svc.cluster.local:5000/users
kubectl exec -it postgres-0 -n db --   wget -qO- http://backend-service.backend.svc.cluster.local:5000/users
ls
cd 05-frontend/
ls
cd ..
kubectl exec -it postgres-0 -n db --   wget -qO- http://backend-service.backend.svc.cluster.local:5000/health/live
cat > 05-frontend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: shobitk/frontend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: BACKEND_URL
          valueFrom:
            configMapKeyRef:
              name: frontend-config
              key: BACKEND_URL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /nginx-health
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 30
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /nginx-health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          failureThreshold: 3
EOF

cat > 05-frontend/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: frontend
spec:
  selector:
    app: frontend
  type: NodePort
  ports:
  - port: 8080
    targetPort: 8080
    nodePort: 30000
    protocol: TCP
EOF

kubectl apply -f 05-frontend/deployment.yaml
kubectl apply -f 05-frontend/service.yaml
kubectl get pods -n frontend 
kubectl get pods -n frontend -w
kubectl get pods -n frontend 
cat ~/k3s-manifests/05-frontend/deployment.yaml | grep -A3 "livenessProbe\|readinessProbe"
cat > ~/k3s-manifests/05-frontend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: shobitk/frontend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 8080
        env:
        - name: BACKEND_URL
          valueFrom:
            configMapKeyRef:
              name: frontend-config
              key: BACKEND_URL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 20
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 5
EOF

kubectl apply -f ~/k3s-manifests/05-frontend/deployment.yaml
kubectl apply -f ~/k3s-manifests/05-frontend/service.yaml
kubectl get pods -n frontend 
# Get a running frontend pod (even 0/1)
FPOD=$(kubectl get pods -n frontend -o jsonpath='{.items[0].metadata.name}')
echo "Pod: $FPOD"
# Check what port nginx is actually listening on
kubectl exec -it $FPOD -n frontend -- sh -c "netstat -tlnp 2>/dev/null || ss -tlnp"
# Try port 80
kubectl exec -it $FPOD -n frontend -- wget -qO- http://localhost:80/ 2>&1 | head -5
# Try port 8080
kubectl exec -it $FPOD -n frontend -- wget -qO- http://localhost:8080/ 2>&1 | head -5
# Check nginx config
kubectl exec -it $FPOD -n frontend -- cat /etc/nginx/conf.d/default.conf 2>/dev/null | grep listen
# Delete everything cleanly
kubectl delete deployment frontend -n frontend
kubectl delete service frontend-service -n frontend 2>/dev/null
sleep 15
kubectl get pods -n frontend
# Must show: No resources found
# Write corrected deployment — port 80
cat > ~/k3s-manifests/05-frontend/deployment.yaml << 'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: frontend
  namespace: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: frontend
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  template:
    metadata:
      labels:
        app: frontend
    spec:
      containers:
      - name: frontend
        image: shobitk/frontend:latest
        imagePullPolicy: Always
        ports:
        - containerPort: 80
        env:
        - name: BACKEND_URL
          valueFrom:
            configMapKeyRef:
              name: frontend-config
              key: BACKEND_URL
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 20
          periodSeconds: 30
          timeoutSeconds: 5
          failureThreshold: 5
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 5
EOF

# Write corrected service — port 80
cat > ~/k3s-manifests/05-frontend/service.yaml << 'EOF'
apiVersion: v1
kind: Service
metadata:
  name: frontend-service
  namespace: frontend
spec:
  selector:
    app: frontend
  type: NodePort
  ports:
  - port: 80
    targetPort: 80
    nodePort: 30000
    protocol: TCP
EOF

# Apply both
kubectl apply -f ~/k3s-manifests/05-frontend/deployment.yaml
kubectl apply -f ~/k3s-manifests/05-frontend/service.yaml
# Watch
kubectl get pods -n frontend -w
kubectl get pods -n frontend 
echo "=== ALL PODS ==="
kubectl get pods -A | grep -E "frontend|backend|db"
echo ""
echo "=== Test frontend from cluster ==="
kubectl exec -it postgres-0 -n db --   wget -qO- http://frontend-service.frontend.svc.cluster.local:80/ 2>&1 | head -5
kubectl get configmap frontend-config -n frontend -o yaml
FPOD=$(kubectl get pods -n frontend -o jsonpath='{.items[0].metadata.name}')
kubectl exec -it $FPOD -n frontend -- wget -qO- http://localhost/config.js 2>&1
