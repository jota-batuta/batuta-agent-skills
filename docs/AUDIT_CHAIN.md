# Audit Chain — Cómo funciona

## Cuándo corre

- **Automáticamente**, ANTES de que el agent te entregue el resultado
- **Nunca necesitás pedirlo** — el agent lo invoca solo
- Los thresholds son configurables en `hooks/plugin-config.json` → `audit.*`

| Tu cambio | Qué pasa | Quién revisa |
|---|---|---|
| ≤20 líneas, trivial (typo, CSS, rename) | No corre audit | Vos directamente |
| 21–50 líneas, ≤2 archivos | Audit LITE | code-reviewer |
| >50 líneas o >2 archivos | Audit FULL | test-engineer → code-reviewer → security-auditor |
| Solo docs (.md, .txt, .yml) | No corre audit | Vos directamente |

## El flujo completo

```
Vos pedís trabajo
  ↓
Intent capture (¿trivial o standard?)
  ↓
Implementer escribe código (Haiku para trivial, Sonnet para standard)
  ↓
git diff --staged --stat → evalúa threshold
  ↓
┌──────────────────────────────────────┐
│ ≤20 LOC + trivial    → sin audit    │
│ 21-50 LOC + ≤2 files → LITE        │
│ >50 LOC o >2 files   → FULL        │
│ solo docs             → sin audit    │
└──────────────────────────────────────┘
  ↓
Si LITE:  code-reviewer (Sonnet)
Si FULL:  test-engineer → code-reviewer → security-auditor (Sonnet × 3, secuencial)
  ↓
Cada gate: APPROVED o BLOCKED
  ↓
BLOCKED → implementer corrige → chain reinicia
APPROVED → te entrego el resultado + abro PR
```

## Qué pasa si un auditor bloquea

El implementer corrige automáticamente y el chain reinicia desde GATE 1. Vos solo ves el resultado final. Si después de 2 intentos sigue bloqueado, el agent te consulta con los findings.

## Cómo invocar manualmente

Para forzar una revisión en un cambio chico, o revisar algo que ya está en el repo:

| Comando | Qué invoca |
|---|---|
| `/review` | code-reviewer — five-axis review |
| `/security-review` | security-auditor — OWASP + vulnerabilities |
| `/test` | test-engineer — coverage + test writing |

## Configuración

Los thresholds se definen en `hooks/plugin-config.json`:

```json
"audit": {
  "skip_threshold_loc": 20,
  "lite_threshold_loc": 50,
  "lite_threshold_files": 2,
  "docs_only_extensions": [".md", ".txt", ".yml", ".yaml"],
  "full_chain": ["test-engineer", "code-reviewer", "security-auditor"],
  "lite_chain": ["code-reviewer"]
}
```

Para cambiar un threshold, editá el JSON. Los hooks y skills leen de ahí.
