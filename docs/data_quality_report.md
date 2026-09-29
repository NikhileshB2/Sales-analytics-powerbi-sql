# Data Quality Report

| Check | Count | Severity | Status |
|---|---:|---|---|
| Row count | 2,000 | INFO | INFO |
| Duplicate order IDs | 0 | ERROR | PASS |
| Null / blank key fields | 0 | ERROR | PASS |
| Quantity or unit price <= 0 | 0 | ERROR | PASS |
| Discount outside 0-100% | 0 | ERROR | PASS |
| Revenue differs from qty x price x (1 - discount) beyond rounding tolerance | 0 | ERROR | PASS |
| Revenue differs by a few cents (price rounding, within tolerance) | 239 | INFO | INFO |
| Salesperson working in more than one region | 0 | INFO | INFO |
| Product mapped to more than one category | 0 | ERROR | PASS |
