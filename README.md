# VPS docker base

## Description

Base configuration for a host running Docker services behind Traefik, with Portainer for management.

Supports two modes:

| Mode | When to use | Certificates | Domains |
|------|-------------|--------------|---------|
| **Local** | Development on a workstation | [mkcert](https://github.com/FiloSottile/mkcert) self-signed | `*.docker.localhost` / `*.local` |
| **Production** | Public VPS with a real domain | Let's Encrypt (ACME TLS challenge) | Any public FQDN |

The base `docker-compose.yml` is the **local** configuration. The `docker-compose.prod.yml` file is a Compose override that adds the ACME resolver on top of it.

---

## Requirements

- Docker and Docker Compose v2
- `make`
- **Local mode only:** [mkcert](https://github.com/FiloSottile/mkcert) (`brew install mkcert` / `apt install mkcert`)
- **Production mode only:** A domain name with DNS pointing to the server's public IP

---

## Quick start

### Local development

```bash
# 1. Clone and enter the repo
git clone <repo-url> && cd traefik-portainer-docker

# 2. Run setup (creates .env, acme.json, Docker network, mkcert certs)
make setup-local

# 3. Edit .env — set TRAEFIK_USERNAME and TRAEFIK_PASSWORD (see below)
#    DOMAIN_NAME and USER_EMAIL can be left empty for local mode

# 4. Start
make up-local
```

Services will be available at:
- Traefik dashboard: `https://traefik.docker.localhost`
- Portainer: `https://portainer.docker.localhost`

> `make setup-local` runs `mkcert -install` automatically, which installs the CA into the **Linux/macOS trust store**. See the [Trusting the certificate](#trusting-the-certificate-locally) section below if you are on WSL2 and using Chrome or Edge on Windows.

---

### Trusting the certificate locally

The mkcert certificates are only valid once the mkcert root CA is trusted by the system opening the URL.

#### Native Linux / macOS

`mkcert -install` (run automatically by `make setup-local`) adds the CA to the system store. No further action needed.

#### WSL2 (Chrome / Edge on Windows)

WSL2 containers bind through Docker Desktop's VM. The browser runs on **Windows** and uses the **Windows certificate store**, which does not know about the Linux mkcert CA.

Run once after `make setup-local`:

```bash
make trust-ca-windows
```

This copies `rootCA.pem` to your Windows Desktop as `mkcert-rootCA.crt`. Then on Windows:

1. Double-click `mkcert-rootCA.crt` on the Desktop
2. **Install Certificate** → **Local Machine** → Next
3. **Place all certificates in the following store** → Browse → **Trusted Root Certification Authorities** → OK
4. Finish → confirm the security prompt
5. **Restart Chrome / Edge**

All `*.docker.localhost` and `*.local` subdomains will now show as secure.

---

### Production (public FQDN + Let's Encrypt)

```bash
# 1. Clone and enter the repo
git clone <repo-url> && cd traefik-portainer-docker

# 2. Run setup (creates .env, acme.json, Docker network)
make setup-prod

# 3. Edit .env — fill in all variables (see below)

# 4. Start
make up-prod
```

Services will be available at:
- Traefik dashboard: `https://traefik.<DOMAIN_NAME>`
- Portainer: `https://portainer.<DOMAIN_NAME>`

---

## Configuration

### `.env` variables

Copy `.env.example` to `.env` (done automatically by `make setup-*`) and fill in:

| Variable | Description | Local | Production |
|----------|-------------|-------|------------|
| `DOMAIN_NAME` | Base domain for service subdomains | leave empty | required |
| `USER_EMAIL` | Email for Let's Encrypt registration | leave empty | required |
| `TRAEFIK_USERNAME` | Traefik dashboard username | required | required |
| `TRAEFIK_PASSWORD` | Traefik dashboard password (hashed) | required | required |

### Generating the Traefik dashboard password

```bash
htpasswd -n <username>
```

The command prints `<username>:<password-hash>` on one line:
- copy the part **before** the `:` into `TRAEFIK_USERNAME`
- copy the part **after** the `:` into `TRAEFIK_PASSWORD`

**Replace every `$` with `$$` in `TRAEFIK_PASSWORD`** to escape it for Docker Compose.

---

## Deploying additional services

Any service on the `traefik` Docker network with `traefik.enable=true` labels will be picked up automatically. See [whoami/docker-compose.yml](whoami/docker-compose.yml) for a minimal example.

For **production**, add `traefik.http.routers.<name>.tls.certresolver=letsencrypt` to each service's labels (in addition to `tls=true`).

---

## Makefile reference

```
make setup-local        Set up for local development (runs mkcert)
make setup-prod         Set up for production
make up-local           Start services in local mode
make up-prod            Start services in production mode
make down               Stop all services
make logs               Follow Traefik logs
make trust-ca-windows   (WSL2) Copy mkcert root CA to Windows Desktop for Chrome/Edge trust
```


