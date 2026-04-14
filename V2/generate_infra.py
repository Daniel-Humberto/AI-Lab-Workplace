import os
import textwrap

def create_file(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w') as f:
        f.write(textwrap.dedent(content).lstrip())

def generate():
    k8s_dir = "infra/k8s"
    create_file(f"{k8s_dir}/namespace.yaml", """
        apiVersion: v1
        kind: Namespace
        metadata:
          name: neuralytics
    """)
    create_file(f"{k8s_dir}/configmap.yaml", """
        apiVersion: v1
        kind: ConfigMap
        metadata:
          name: neuralytics-config
          namespace: neuralytics
        data:
          API_PORT: "8000"
          ENVIRONMENT: "production"
          OLLAMA_BASE_URL: "http://ollama:11434"
          QDRANT_URL: "http://qdrant:6333"
    """)
    create_file(f"{k8s_dir}/secrets.yaml.template", """
        apiVersion: v1
        kind: Secret
        metadata:
          name: neuralytics-secrets
          namespace: neuralytics
        type: Opaque
        data:
          # Base64 encoded values
          SECRET_KEY: "Y2hhbmdlX3RoaXNfdG9fYV9zZWN1cmVfcmFuZG9tX3N0cmluZw=="
    """)
    create_file(f"{k8s_dir}/ingress.yaml", """
        apiVersion: networking.k8s.io/v1
        kind: Ingress
        metadata:
          name: neuralytics-ingress
          namespace: neuralytics
          annotations:
            kubernetes.io/ingress.class: nginx
        spec:
          rules:
          - host: api.neuralytics.local
            http:
              paths:
              - path: /
                pathType: Prefix
                backend:
                  service:
                    name: fastapi-gateway
                    port:
                      number: 8000
    """)
    create_file(f"{k8s_dir}/hpa.yaml", """
        apiVersion: autoscaling/v2
        kind: HorizontalPodAutoscaler
        metadata:
          name: fastapi-gateway-hpa
          namespace: neuralytics
        spec:
          scaleTargetRef:
            apiVersion: apps/v1
            kind: Deployment
            name: fastapi-gateway
          minReplicas: 1
          maxReplicas: 5
          metrics:
          - type: Resource
            resource:
              name: cpu
              target:
                type: Utilization
                averageUtilization: 70
    """)
    create_file(f"{k8s_dir}/pvc.yaml", """
        apiVersion: v1
        kind: PersistentVolumeClaim
        metadata:
          name: qdrant-pvc
          namespace: neuralytics
        spec:
          accessModes: [ "ReadWriteOnce" ]
          resources:
            requests:
              storage: 10Gi
    """)
    
    # Just a sample deployment and service for fastapi-gateway to show K8s readiness
    create_file(f"{k8s_dir}/deployments/fastapi-gateway.yaml", """
        apiVersion: apps/v1
        kind: Deployment
        metadata:
          name: fastapi-gateway
          namespace: neuralytics
        spec:
          replicas: 2
          selector:
            matchLabels:
              app: fastapi-gateway
          template:
            metadata:
              labels:
                app: fastapi-gateway
            spec:
              containers:
              - name: fastapi-gateway
                image: neuralytics/fastapi-gateway:latest
                ports:
                - containerPort: 8000
                envFrom:
                - configMapRef:
                    name: neuralytics-config
    """)
    create_file(f"{k8s_dir}/services/fastapi-gateway.yaml", """
        apiVersion: v1
        kind: Service
        metadata:
          name: fastapi-gateway
          namespace: neuralytics
        spec:
          type: LoadBalancer
          selector:
            app: fastapi-gateway
          ports:
          - port: 80
            targetPort: 8000
    """)

    tf_dir = "infra/terraform"
    create_file(f"{tf_dir}/main.tf", """
        module "eks" {
          source = "./modules/eks"
          cluster_name = var.cluster_name
        }
    """)
    create_file(f"{tf_dir}/variables.tf", """
        variable "cluster_name" {
          description = "Name of the EKS cluster"
          type        = string
          default     = "neuralytics-eks"
        }
    """)
    create_file(f"{tf_dir}/outputs.tf", """
        output "cluster_endpoint" {
          description = "EKS Cluster Endpoint"
          value       = module.eks.endpoint
        }
    """)
    create_file(f"{tf_dir}/modules/eks/main.tf", """
        # Placeholder for AWS EKS terraform logic
        output "endpoint" { value = "https://eks.example.com" }
    """)

    print("Generation complete!")

if __name__ == "__main__":
    generate()
