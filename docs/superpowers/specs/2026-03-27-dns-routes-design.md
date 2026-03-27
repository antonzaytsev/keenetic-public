# DNS Routes UI — Design Spec

**Date:** 2026-03-27
**Gem version:** keenetic 1.1.0 (SHA 3a952837c793)

---

## Overview

Add a DNS Routes page that lets users manage domain-based routing on the Keenetic router. The router resolves configured domains and automatically installs floating IP routes to the target interface — enabling split-tunnel VPN and similar setups without manual IP entry.

Two entities are managed:

- **Domain Groups** (`object-group fqdn`) — named lists of FQDNs, e.g. "YouTube" = `["youtube.com", "googlevideo.com"]`
- **DNS Routes** (`dns-proxy route`) — maps a domain group to a network interface, e.g. "YouTube" → `Wireguard0`

---

## Data Model

### DomainGroup
```
name: string          // internal identifier, e.g. "domain-list0"
description: string   // human label, e.g. "YouTube"
domains: string[]     // list of FQDNs
```

### DnsRoute
```
index: string         // opaque MD5 identifier used for deletion
group: string         // references a DomainGroup name
interface: string     // target network interface, e.g. "Wireguard0"
auto: boolean | null  // auto-managed by router
comment: string | null
```

---

## Backend

New route block in `backend/app.rb` under `/api/dns-routes`:

| Method | Path | Gem call |
|--------|------|----------|
| GET | `/api/dns-routes/domain-groups` | `client.dns_routes.domain_groups` |
| POST | `/api/dns-routes/domain-groups` | `client.dns_routes.create_domain_group(name:, description:, domains:)` |
| DELETE | `/api/dns-routes/domain-groups/:name` | `client.dns_routes.delete_domain_group(name:)` |
| GET | `/api/dns-routes/routes` | `client.dns_routes.routes` |
| POST | `/api/dns-routes/routes` | `client.dns_routes.add_route(group:, interface:, comment:)` |
| DELETE | `/api/dns-routes/routes/:index` | `client.dns_routes.delete_route(index:)` |

POST `/domain-groups` also handles **edit** (same name overwrites the existing group in Keenetic).

---

## Frontend

### New files
- `frontend/src/pages/DnsRoutes.tsx`
- `frontend/src/pages/DnsRoutes.css`
- `frontend/src/hooks/useDnsRoutes.ts`

### Modified files
- `frontend/src/api/types.ts` — add `DomainGroup`, `DnsRoute`, and response types
- `frontend/src/hooks/index.ts` — export new hooks
- `frontend/src/pages/index.ts` — export `DnsRoutes`
- `frontend/src/App.tsx` — add `/dns-routes` route
- `frontend/src/components/layout/Sidebar.tsx` — add "DNS Routes" nav item between Routing and Policies

### Page structure

**URL:** `/dns-routes`
**Header:** "DNS Routes" / subtitle shows counts

**Two tabs** (hash-based, same pattern as Routes page):
- `#groups` — Domain Groups
- `#routes` — DNS Routes

#### Domain Groups tab
Table columns: Name, Description, Domains (comma-separated preview, truncated), Actions (edit, delete)

- "Create group" button top-right
- Create/Edit modal: Name field, Description field, Domains textarea (one domain per line)
- Edit populates form with existing values; submits same `POST /domain-groups` (overwrite)
- Delete confirms inline (no separate confirm dialog — matches existing patterns)

#### DNS Routes tab
Table columns: Domain Group, Interface, Auto, Comment, Actions (delete)

- "Add route" button top-right
- Create modal: Domain Group dropdown (populated from domain groups), Interface dropdown (populated from network interfaces), Comment field (optional)
- No edit — delete and recreate

### Hooks (`useDnsRoutes.ts`)
- `useDomainGroups()` — query, refetchInterval 30s
- `useDnsRoutes()` — query, refetchInterval 30s
- `useCreateDomainGroup()` — mutation, invalidates domain-groups
- `useDeleteDomainGroup()` — mutation, invalidates domain-groups
- `useAddDnsRoute()` — mutation, invalidates dns-routes
- `useDeleteDnsRoute()` — mutation, invalidates dns-routes

---

## Out of Scope

- Batch create/delete
- Reordering groups or routes
- Viewing resolved IPs (that's the routing table, already on the Routes page)
