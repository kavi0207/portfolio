# Cyber Threat-Intelligence Data Pipelines, Portfolio

Three production-grade **data pipelines** I built inside a Python monorepo, each solving a distinct cybersecurity problem. Common backbone: **Python 3.12 · Dagster orchestration · dlt + SQLAlchemy · BigQuery/PostgreSQL · LLM enrichment**.

| Project | The cyber problem it solves | One-line architecture |
|---|---|---|
| **[Threat-Intel](threat-intel.md)** | *Which of 270k known CVEs should I patch first?* | 12+ feeds → enrich → LLM → **0–100 risk score** in Postgres |
| **[Threat-Event](threat-event.md)** | *Who got breached, in what industry, by which actor?* | Scrapy/API crawl → **bronze/silver/gold** medallion → normalized Postgres graph |
| **[Dark-Owl](dark-owl.md)** | *Are my company's credentials leaking on the dark web?* | DarkOwl API → **dedup + Gemini role triage** → Pub/Sub alerts |

Each write-up opens with a rendered architecture diagram and is written from a data-pipeline-engineering perspective: sources, transformations, orchestration, storage, and the design decisions that matter.

## Themes across all three

- **Multi-source data integration**, REST APIs, CSV/STIX/XML feeds, web crawling, and a darknet API, each with bespoke incremental-sync, retry, and rate-limit logic.
- **Dagster asset graphs**, dependency-aware scheduling, sensors, retry policies, and containerized gRPC deployment.
- **Pragmatic LLM use**, Claude and Gemini applied *surgically* (gap-filling, entity validation, role classification) with structured output, batching, caching, and full auditability, never as a black box.
- **Clean serving layers**, normalized PostgreSQL schemas designed so the questions security teams actually ask become simple queries.

## Diagrams

All diagrams are authored as Mermaid (`diagrams/*.mmd`) and rendered to PNG (`diagrams/*.png`) for easy embedding in Medium or slides.
