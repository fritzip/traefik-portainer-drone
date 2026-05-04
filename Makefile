COMPOSE_LOCAL = docker compose
COMPOSE_PROD  = docker compose -f docker-compose.yml -f docker-compose.prod.yml

.PHONY: help setup-local setup-prod up-local up-prod down logs trust-ca-windows

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(firstword $(MAKEFILE_LIST)) | sort | \
	  awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# ─── Local development ────────────────────────────────────────────────────────

setup-local: ## Set up for local development (requires mkcert)
	@echo "--- Copying .env.example to .env (skipped if .env already exists)..."
	@cp -n .env.example .env 2>/dev/null && echo "  Created .env — fill in TRAEFIK_USERNAME and TRAEFIK_PASSWORD." || echo "  .env already exists, skipping."
	@echo "--- Creating traefik-config/acme.json with correct permissions..."
	@touch traefik-config/acme.json && chmod 600 traefik-config/acme.json
	@echo "--- Creating Docker network 'traefik'..."
	@docker network inspect traefik >/dev/null 2>&1 \
	  && echo "  Network 'traefik' already exists, skipping." \
	  || docker network create traefik
	@echo "--- Creating /var/log/traefik directory..."
	@sudo mkdir -p /var/log/traefik
	@echo "--- Installing mkcert root CA into the local trust store..."
	@mkcert -install
	@echo "--- Generating local TLS certificates with mkcert..."
	@mkdir -p traefik-config/certs
	@mkcert \
	  -cert-file traefik-config/certs/local-cert.pem \
	  -key-file  traefik-config/certs/local-key.pem \
	  "*.docker.localhost" "*.local"
	@echo ""
	@echo "Local setup complete."
	@echo "Edit .env if needed, then run:  make up-local"
	@echo ""
	@echo "WSL2 users: run 'make trust-ca-windows' to trust the CA in Chrome/Edge on Windows."

up-local: ## Start services in local mode (mkcert certs, *.docker.localhost domains)
	$(COMPOSE_LOCAL) up -d

# ─── Production ───────────────────────────────────────────────────────────────

setup-prod: ## Set up for production (DOMAIN_NAME and USER_EMAIL required in .env)
	@echo "--- Copying .env.example to .env (skipped if .env already exists)..."
	@cp -n .env.example .env 2>/dev/null && echo "  Created .env — fill in all variables before starting." || echo "  .env already exists, skipping."
	@echo "--- Creating traefik-config/acme.json with correct permissions..."
	@touch traefik-config/acme.json && chmod 600 traefik-config/acme.json
	@echo "--- Creating Docker network 'traefik'..."
	@docker network inspect traefik >/dev/null 2>&1 \
	  && echo "  Network 'traefik' already exists, skipping." \
	  || docker network create traefik
	@echo "--- Creating /var/log/traefik directory..."
	@sudo mkdir -p /var/log/traefik
	@echo ""
	@echo "Production setup complete."
	@echo "Ensure DOMAIN_NAME, USER_EMAIL, TRAEFIK_USERNAME, and TRAEFIK_PASSWORD are set in .env, then run:  make up-prod"

up-prod: ## Start services in production mode (Let's Encrypt, requires a public FQDN in .env)
	$(COMPOSE_PROD) up -d

# ─── Shared ───────────────────────────────────────────────────────────────────

down: ## Stop all services
	docker compose down

logs: ## Follow Traefik logs
	docker logs -f traefik

trust-ca-windows: ## (WSL2) Copy mkcert root CA to Windows Desktop for Chrome/Edge trust
	@CAROOT=$$(mkcert -CAROOT) && \
	  WIN_USER=$$(cmd.exe /c "echo %USERPROFILE%" 2>/dev/null | tr -d '\r') && \
	  WIN_DESKTOP=$$(wslpath "$$WIN_USER/Desktop") && \
	  cp "$$CAROOT/rootCA.pem" "$$WIN_DESKTOP/mkcert-rootCA.crt" && \
	  echo "" && \
	  echo "Copied to $$WIN_DESKTOP/mkcert-rootCA.crt" && \
	  echo "" && \
	  echo "On Windows:" && \
	  echo "  1. Double-click mkcert-rootCA.crt on your Desktop" && \
	  echo "  2. Install Certificate -> Local Machine -> Trusted Root Certification Authorities" && \
	  echo "  3. Restart Chrome / Edge"
