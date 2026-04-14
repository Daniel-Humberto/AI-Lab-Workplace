.PHONY: up down logs test k8s-deploy tf-plan lint docs

up:
	# Starts all Docker Compose services in detached mode
	docker compose up -d --build

down:
	# Removes all Docker Compose containers and volumes
	docker compose down -v

logs:
	# Follow logs for all containers
	docker compose logs -f

test:
	# Run integration and smoke tests
	pytest tests/ -v --tb=short

k8s-deploy:
	# Apply Kubernetes manifests
	kubectl apply -f infra/k8s/

tf-plan:
	# Run terraform plan
	terraform -chdir=infra/terraform plan

lint:
	# Run linters formatted correctly
	ruff check . && black --check .

docs:
	# Generates an API docs snapshot if backend is running
	curl -s http://localhost:8000/openapi.json > docs/openapi.json
