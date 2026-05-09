---
name: agent-heartbeat-autonomy
description: Use when designing Capa 6 (Agent Heartbeating / Execution Autonomy): decide prompt-based vs true autonomous unattended execution (cron-driven heartbeat prompt injection) for B2B automation.
---

# Agent Heartbeat & Execution Autonomy

## Overview

Capa 6: For B2B unattended automation, the agent must be able to wake itself without human intervention. This layer forces an explicit decision between prompt-based (operator-driven) and autonomous (cron + heartbeat prompt injection) execution modes.

## When to Use

- Any agent intended for production unattended operation (scheduled jobs, event-driven pipelines, SLA-bound processes).

## Process

1. At harness design time, choose execution mode:
   - Prompt-based: operator or system triggers the agent.
   - Autonomous: cron job injects a heartbeat prompt that wakes the agent, checks state, and decides next action.
2. Document the chosen mode and the heartbeat schedule.
3. Ensure crash recovery and retry logic works in autonomous mode.

## Verification

- Autonomous agents have a documented cron + heartbeat mechanism.
- No human action is required to keep the agent running.