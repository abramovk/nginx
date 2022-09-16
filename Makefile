build:
	@echo "Building Nginx Docker images (linux/amd64)..."
	@docker buildx build -t abramovk/nginx:latest -t abramovk/nginx:1.22.0 --platform linux/amd64 --compress --no-cache -f Dockerfile . --push
.PHONY: build