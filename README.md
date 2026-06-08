# IaC Mangxo — Infraestructura AWS con Terraform

Infraestructura para `mango-api` y `mango-admin` sobre ECS Fargate

## Estructura del repositorio

```
mango-infra/
├── modules/
│   ├── vpc/          # VPC, subredes, IGW, NAT Gateway, Route Tables
│   ├── sg/           # Security Groups
│   ├── ecr/          # Repositorios ECR privados
│   ├── alb/          # Application Load Balancer, Target Groups, Listeners
│   ├── ecs/          # Cluster, Task Definitions, Services, EventBridge
│   └── sqs/          # Colas SQS para workers (opcional)
├── environments/
│   ├── prod/         # terraform.tfvars + main.tf de producción
│   └── dev/          # terraform.tfvars + main.tf de desarrollo
└── README.md
```

---

## Arquitectura

```
Internet
   │
   ▼ 443 (SSL terminado en ALB con ACM) | (DESPUES SE CREA) | (POR AHORA PORT:80)
┌────────────────────────────────────────────┐
│     Application Load Balancer (público)    │
│  Listener: api.mango.com → TG mango-api    │
│  Listener: admin.mango.com → TG mango-admin│  
└────────────┬───────────────────────────────┘   
             │ subredes públicas (us-east-1a / 1b)
             ▼
┌─────────────────────────────────────────┐
│            ECS Cluster (Fargate)        │
│  Subredes privadas (us-east-1a / 1b)    │
│                                         │
│  mango-api       (min 2 / max 4, AS)    │
│  mango-admin     (1 fija, sin AS)       │
│  mango-api-worker(1 fija, SQS)          │
│  mango-admin-worker(1 fija, SQS)        │
│  cron-task       (EventBridge → Fargate)│
└────────────┬────────────────────────────┘
             │ subredes privadas
             ▼
        RDS (creada en terraform)     SQS Queues (Creo que tmb se crea con Terraform)
```

---

## Prerrequisitos

- ARN del certificado ACM disponible 
- Dominios de las api
- No me acuerdo
- RDS existente (se necesita el Security Group ID)

## Variables obligatorias

| Variable | Descripción |
|---|---|
| `acm_certificate_arn` | ARN del certificado ACM existente |
| `rds_security_group_id` | SG ID de la RDS existente (para permitir acceso) |
| `api_domain` | Dominio de mango-api (ej: `api.mango.com`) |
| `admin_domain` | Dominio de mango-admin (ej: `admin.mango.com`) |
| `admin_allowed_cidrs` | Lista de CIDRs con acceso a mango-admin (vacío = público) |

---

## Decisiones de diseño

| Tema | Decisión |
|---|---|
| NAT Gateway | 1 solo con EIP fija (ahorro de costos) |
| Workers | Misma imagen ECR que su app, distinto `command` |
| Cron | EventBridge Scheduler dispara ECS Task (Fargate) |
| SQS | Terraform crea las colas (controlado por variable `create_sqs`) |
| mango-admin acceso | Variable `admin_allowed_cidrs` — vacío = público, IPs = whitelist |
| Auto-scaling | Solo mango-api en PROD (CPU 80%, min 2, max 4) |

---

## Outputs principales

Después de `terraform apply`:

```bash
terraform output alb_dns_name        # DNS del ALB
terraform output ecr_api_url         # URL para docker push mango-api
terraform output ecr_admin_url       # URL para docker push mango-admin
terraform output ecs_cluster_name    # Nombre del cluster
```
