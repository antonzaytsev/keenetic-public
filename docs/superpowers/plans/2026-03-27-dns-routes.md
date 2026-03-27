# DNS Routes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a DNS Routes page to manage FQDN domain groups and their interface routing rules, backed by the new `client.dns_routes` gem resource.

**Architecture:** New `/api/dns-routes` backend block in `app.rb` exposes 6 endpoints. Frontend adds types, hooks, and a tabbed page (`/dns-routes`) following the same patterns as the existing Routes page. Navigation sidebar gains a "DNS Routes" link.

**Tech Stack:** Ruby/Roda backend, React/TypeScript frontend, @tanstack/react-query, WebMock for backend tests.

---

## File Map

| File | Action | Responsibility |
|------|--------|----------------|
| `backend/app.rb` | Modify | Add `/api/dns-routes` route block (6 endpoints) |
| `backend/spec/integration/api_spec.rb` | Modify | Add tests for all 6 endpoints |
| `frontend/src/api/types.ts` | Modify | Add `DomainGroup`, `DnsRoute`, 4 response types |
| `frontend/src/hooks/useDnsRoutes.ts` | Create | 6 query/mutation hooks |
| `frontend/src/hooks/index.ts` | Modify | Export new hooks |
| `frontend/src/pages/DnsRoutes.tsx` | Create | Tabbed page: Domain Groups + DNS Routes |
| `frontend/src/pages/DnsRoutes.css` | Create | Styles (reuse existing route CSS patterns) |
| `frontend/src/pages/index.ts` | Modify | Export `DnsRoutes` |
| `frontend/src/App.tsx` | Modify | Add `/dns-routes` React Router route |
| `frontend/src/components/layout/Sidebar.tsx` | Modify | Add "DNS Routes" nav item |

---

## Task 1: Backend endpoints

**Files:**
- Modify: `backend/app.rb` (after the `routing` block, around line 594)
- Modify: `backend/spec/integration/api_spec.rb` (append new describe blocks)

- [ ] **Step 1: Add the dns-routes route block to app.rb**

Insert this block after the closing `end` of the `r.on 'routing'` block (before the final `end` of `r.on 'api'`):

```ruby
      # DNS Routes endpoints
      r.on 'dns-routes' do
        r.on 'domain-groups' do
          r.is do
            # GET /api/dns-routes/domain-groups
            r.get do
              groups = keenetic_client.dns_routes.domain_groups
              {
                domain_groups: groups,
                count: groups.size,
                timestamp: Time.now.iso8601
              }
            end

            # POST /api/dns-routes/domain-groups - create or update group
            r.post do
              params = r.params
              name = params['name']
              description = params['description']
              domains_raw = params['domains']

              if name.nil? || name.strip.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'name is required',
                  timestamp: Time.now.iso8601
                }
              end

              if description.nil? || description.strip.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'description is required',
                  timestamp: Time.now.iso8601
                }
              end

              domains = case domains_raw
                        when Array then domains_raw.map(&:to_s).reject(&:empty?)
                        when String then domains_raw.split(/[\n,]+/).map(&:strip).reject(&:empty?)
                        else []
                        end

              if domains.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'at least one domain is required',
                  timestamp: Time.now.iso8601
                }
              end

              keenetic_client.dns_routes.create_domain_group(
                name: name,
                description: description,
                domains: domains
              )
              {
                success: true,
                timestamp: Time.now.iso8601
              }
            end
          end

          r.on String do |name_param|
            name = URI.decode_www_form_component(name_param)

            # DELETE /api/dns-routes/domain-groups/:name
            r.delete do
              keenetic_client.dns_routes.delete_domain_group(name: name)
              {
                success: true,
                timestamp: Time.now.iso8601
              }
            end
          end
        end

        r.on 'routes' do
          r.is do
            # GET /api/dns-routes/routes
            r.get do
              routes = keenetic_client.dns_routes.routes
              {
                routes: routes,
                count: routes.size,
                timestamp: Time.now.iso8601
              }
            end

            # POST /api/dns-routes/routes
            r.post do
              params = r.params
              group = params['group']
              interface = params['interface']
              comment = params['comment'] || ''

              if group.nil? || group.strip.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'group is required',
                  timestamp: Time.now.iso8601
                }
              end

              if interface.nil? || interface.strip.empty?
                response.status = 400
                next {
                  error: 'Bad Request',
                  message: 'interface is required',
                  timestamp: Time.now.iso8601
                }
              end

              keenetic_client.dns_routes.add_route(
                group: group,
                interface: interface,
                comment: comment
              )
              {
                success: true,
                timestamp: Time.now.iso8601
              }
            end
          end

          r.on String do |index_param|
            index = URI.decode_www_form_component(index_param)

            # DELETE /api/dns-routes/routes/:index
            r.delete do
              keenetic_client.dns_routes.delete_route(index: index)
              {
                success: true,
                timestamp: Time.now.iso8601
              }
            end
          end
        end
      end
```

- [ ] **Step 2: Add backend tests**

Append to `backend/spec/integration/api_spec.rb` before the final `end`:

```ruby
  # ──────────────────────────────────────────────────────────────────────────
  # DNS Routes
  # ──────────────────────────────────────────────────────────────────────────

  describe 'GET /api/dns-routes/domain-groups' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [
          {
            'show' => { 'sc' => { 'object-group' => { 'fqdn' => {
              'domain-list0' => {
                'description' => 'YouTube',
                'include' => [{ 'address' => 'youtube.com' }, { 'address' => 'googlevideo.com' }]
              }
            } } } }
          }
        ].to_json)
    end

    it 'returns list of domain groups' do
      get '/api/dns-routes/domain-groups'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      group = json['domain_groups'].first
      expect(group['name']).to eq('domain-list0')
      expect(group['description']).to eq('YouTube')
      expect(group['domains']).to eq(['youtube.com', 'googlevideo.com'])
    end
  end

  describe 'POST /api/dns-routes/domain-groups' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [{}, {}, {}].to_json)
    end

    it 'creates a domain group' do
      post '/api/dns-routes/domain-groups',
           { name: 'domain-list1', description: 'Netflix', domains: ['netflix.com', 'nflxvideo.net'] }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
    end

    it 'returns 400 when name is missing' do
      post '/api/dns-routes/domain-groups',
           { description: 'Netflix', domains: ['netflix.com'] }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
    end

    it 'returns 400 when domains are empty' do
      post '/api/dns-routes/domain-groups',
           { name: 'domain-list1', description: 'Netflix', domains: [] }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
    end
  end

  describe 'DELETE /api/dns-routes/domain-groups/:name' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [{}, {}, {}].to_json)
    end

    it 'deletes a domain group' do
      delete '/api/dns-routes/domain-groups/domain-list0'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
    end
  end

  describe 'GET /api/dns-routes/routes' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [
          {
            'show' => { 'sc' => { 'dns-proxy' => { 'route' => [
              {
                'group' => 'domain-list0',
                'interface' => 'Wireguard0',
                'auto' => true,
                'index' => 'abc123',
                'comment' => ''
              }
            ] } } }
          }
        ].to_json)
    end

    it 'returns list of dns routes' do
      get '/api/dns-routes/routes'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['count']).to eq(1)
      route = json['routes'].first
      expect(route['group']).to eq('domain-list0')
      expect(route['interface']).to eq('Wireguard0')
      expect(route['index']).to eq('abc123')
    end
  end

  describe 'POST /api/dns-routes/routes' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [{}, {}, {}].to_json)
    end

    it 'creates a dns route' do
      post '/api/dns-routes/routes',
           { group: 'domain-list0', interface: 'Wireguard0', comment: '' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
    end

    it 'returns 400 when group is missing' do
      post '/api/dns-routes/routes',
           { interface: 'Wireguard0' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
    end

    it 'returns 400 when interface is missing' do
      post '/api/dns-routes/routes',
           { group: 'domain-list0' }.to_json,
           'CONTENT_TYPE' => 'application/json'

      expect(last_response.status).to eq(400)
    end
  end

  describe 'DELETE /api/dns-routes/routes/:index' do
    before do
      stub_request(:post, 'http://192.168.1.1/rci/')
        .to_return(status: 200, body: [{}, {}, {}].to_json)
    end

    it 'deletes a dns route' do
      delete '/api/dns-routes/routes/abc123'

      expect(last_response.status).to eq(200)
      json = JSON.parse(last_response.body)
      expect(json['success']).to be true
    end
  end
```

- [ ] **Step 3: Run backend tests**

```bash
cd /Users/anton/code/apps/keenetic-public/backend && bundle exec rspec spec/integration/api_spec.rb
```

Expected: all tests pass (including the new DNS routes tests).

- [ ] **Step 4: Commit**

```bash
cd /Users/anton/code/apps/keenetic-public && git add backend/app.rb backend/spec/integration/api_spec.rb && git commit -m "Add DNS routes backend endpoints"
```

---

## Task 2: Frontend types

**Files:**
- Modify: `frontend/src/api/types.ts` (append after `RebootResponse`)

- [ ] **Step 1: Add types to api/types.ts**

Append after the `RebootResponse` interface (before `// API Error`):

```typescript
// DNS Routes types
export interface DomainGroup {
  name: string;
  description: string | null;
  domains: string[];
}

export interface DomainGroupsResponse {
  domain_groups: DomainGroup[];
  count: number;
  timestamp: string;
}

export interface DnsRoute {
  index: string;
  group: string;
  interface: string | null;
  auto: boolean | null;
  comment: string | null;
}

export interface DnsRoutesResponse {
  routes: DnsRoute[];
  count: number;
  timestamp: string;
}
```

- [ ] **Step 2: Commit**

```bash
cd /Users/anton/code/apps/keenetic-public && git add frontend/src/api/types.ts && git commit -m "Add DNS routes TypeScript types"
```

---

## Task 3: Frontend hooks

**Files:**
- Create: `frontend/src/hooks/useDnsRoutes.ts`
- Modify: `frontend/src/hooks/index.ts`

- [ ] **Step 1: Create frontend/src/hooks/useDnsRoutes.ts**

```typescript
import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { api } from '../api';
import type { DomainGroupsResponse, DnsRoutesResponse } from '../api';

export function useDomainGroups() {
  return useQuery({
    queryKey: ['dns-routes', 'domain-groups'],
    queryFn: () => api.get<DomainGroupsResponse>('/dns-routes/domain-groups'),
    refetchInterval: 30000,
  });
}

export function useDnsRoutes() {
  return useQuery({
    queryKey: ['dns-routes', 'routes'],
    queryFn: () => api.get<DnsRoutesResponse>('/dns-routes/routes'),
    refetchInterval: 30000,
  });
}

interface CreateDomainGroupParams {
  name: string;
  description: string;
  domains: string[];
}

export function useCreateDomainGroup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: CreateDomainGroupParams) =>
      api.post<{ success: boolean }>('/dns-routes/domain-groups', params as Record<string, unknown>),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'domain-groups'] });
    },
  });
}

export function useDeleteDomainGroup() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (name: string) =>
      api.delete<{ success: boolean }>(`/dns-routes/domain-groups/${encodeURIComponent(name)}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'domain-groups'] });
    },
  });
}

interface AddDnsRouteParams {
  group: string;
  interface: string;
  comment?: string;
}

export function useAddDnsRoute() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (params: AddDnsRouteParams) =>
      api.post<{ success: boolean }>('/dns-routes/routes', params as Record<string, unknown>),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'routes'] });
    },
  });
}

export function useDeleteDnsRoute() {
  const queryClient = useQueryClient();
  return useMutation({
    mutationFn: (index: string) =>
      api.delete<{ success: boolean }>(`/dns-routes/routes/${encodeURIComponent(index)}`),
    onSuccess: () => {
      queryClient.invalidateQueries({ queryKey: ['dns-routes', 'routes'] });
    },
  });
}
```

- [ ] **Step 2: Export from hooks/index.ts**

Add this line to `frontend/src/hooks/index.ts`:

```typescript
export { useDomainGroups, useDnsRoutes, useCreateDomainGroup, useDeleteDomainGroup, useAddDnsRoute, useDeleteDnsRoute } from './useDnsRoutes';
```

- [ ] **Step 3: Commit**

```bash
cd /Users/anton/code/apps/keenetic-public && git add frontend/src/hooks/useDnsRoutes.ts frontend/src/hooks/index.ts && git commit -m "Add DNS routes frontend hooks"
```

---

## Task 4: Frontend page

**Files:**
- Create: `frontend/src/pages/DnsRoutes.tsx`
- Create: `frontend/src/pages/DnsRoutes.css`
- Modify: `frontend/src/pages/index.ts`

- [ ] **Step 1: Create frontend/src/pages/DnsRoutes.css**

```css
.dns-routes-page {
  display: flex;
  flex-direction: column;
  gap: var(--spacing-lg);
  min-width: 0;
  overflow: hidden;
}

/* Stats row */
.dns-routes-stats {
  display: flex;
  gap: var(--spacing-md);
  flex-wrap: wrap;
  min-width: 0;
}

.dns-routes-stats > * {
  min-width: 0;
}

.dns-routes-stats__card {
  flex: 1;
  min-width: 150px;
}

/* Tabbed Container */
.dns-routes-tabbed {
  margin-top: 8px;
}

.dns-routes-tabs {
  display: flex;
  gap: 4px;
  padding: 0;
  border-bottom: 1px solid var(--border-color);
}

.dns-routes-tabs__tab {
  display: inline-flex;
  align-items: center;
  gap: 8px;
  padding: 12px 20px;
  border: 1px solid transparent;
  border-bottom: none;
  border-radius: var(--border-radius) var(--border-radius) 0 0;
  background: transparent;
  color: var(--text-secondary);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
  position: relative;
  margin-bottom: -1px;
}

.dns-routes-tabs__tab svg {
  width: 16px;
  height: 16px;
  flex-shrink: 0;
}

.dns-routes-tabs__tab:hover {
  color: var(--text-primary);
  background: rgba(255, 255, 255, 0.04);
}

.dns-routes-tabs__tab--active {
  background: var(--bg-card);
  color: var(--accent-primary);
  border-color: var(--border-color);
}

.dns-routes-tabs__tab--active svg {
  color: var(--accent-primary);
}

.dns-routes-tabs__spacer {
  flex: 1;
}

.dns-routes-tab-content {
  background: var(--bg-card);
  border: 1px solid var(--border-color);
  border-top: none;
  border-radius: 0 0 var(--border-radius) var(--border-radius);
  min-width: 0;
  overflow: hidden;
}

.dns-routes-add-btn {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 8px 16px;
  background: var(--accent-primary);
  color: white;
  border: none;
  border-radius: var(--border-radius);
  font-size: 14px;
  font-weight: 500;
  cursor: pointer;
  transition: all 0.15s ease;
  margin-bottom: -1px;
  align-self: center;
}

.dns-routes-add-btn:hover {
  background: var(--accent-primary-hover);
}

.dns-routes-add-btn svg {
  width: 16px;
  height: 16px;
}

/* Domain group cells */
.dns-group-name {
  font-family: var(--font-mono);
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
}

.dns-group-description {
  font-weight: 500;
  color: var(--color-text-primary);
}

.dns-group-domains {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
  max-width: 300px;
}

.dns-route-group {
  font-weight: 500;
  color: var(--color-text-primary);
}

.dns-route-interface {
  font-weight: 500;
  color: var(--color-info);
}

.dns-route-comment {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
}

/* Actions column */
.dns-actions {
  display: flex;
  align-items: center;
  justify-content: flex-end;
  gap: 4px;
  opacity: 0;
  transition: opacity 0.15s ease;
}

tr:hover .dns-actions {
  opacity: 1;
}

.dns-actions__btn {
  display: flex;
  align-items: center;
  justify-content: center;
  width: 28px;
  height: 28px;
  padding: 0;
  border: none;
  background: transparent;
  border-radius: var(--border-radius);
  color: var(--text-muted);
  cursor: pointer;
  transition: all 0.15s ease;
}

.dns-actions__btn svg {
  width: 16px;
  height: 16px;
}

.dns-actions__btn--edit:hover {
  background: var(--bg-elevated);
  color: var(--accent-primary);
}

.dns-actions__btn--delete:hover {
  background: rgba(239, 68, 68, 0.1);
  color: var(--accent-danger);
}

/* Modal textarea for domains */
.modal-form__textarea {
  width: 100%;
  padding: 8px 12px;
  background: var(--bg-input, var(--color-surface-elevated));
  border: 1px solid var(--border-color);
  border-radius: var(--border-radius);
  color: var(--color-text-primary);
  font-size: 14px;
  font-family: var(--font-mono);
  resize: vertical;
  min-height: 100px;
  box-sizing: border-box;
}

.modal-form__textarea:focus {
  outline: none;
  border-color: var(--accent-primary);
}

.modal-form__hint {
  font-size: var(--font-size-sm);
  color: var(--color-text-muted);
  margin-top: 4px;
}

.modal-form__error {
  padding: 10px 12px;
  background: rgba(239, 68, 68, 0.1);
  border: 1px solid rgba(239, 68, 68, 0.3);
  border-radius: var(--border-radius);
  color: var(--accent-danger);
  font-size: 0.875rem;
}

@media (max-width: 768px) {
  .dns-routes-stats__card {
    min-width: calc(50% - 0.25rem);
    flex: 0 0 calc(50% - 0.25rem);
  }

  .dns-routes-tabs__spacer {
    display: none;
  }

  .dns-routes-add-btn {
    width: 100%;
    justify-content: center;
    order: -1;
    margin-bottom: 0.5rem;
    border-radius: var(--border-radius);
  }

  .dns-actions {
    opacity: 1;
  }

  .dns-group-domains {
    max-width: 150px;
  }
}

@media (max-width: 480px) {
  .dns-routes-stats__card {
    min-width: 100%;
    flex: 0 0 100%;
  }
}
```

- [ ] **Step 2: Create frontend/src/pages/DnsRoutes.tsx**

```typescript
import { useEffect, useState } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { Header } from '../components/layout';
import { Card, Table, type Column, Modal } from '../components/ui';
import {
  useDomainGroups,
  useDnsRoutes,
  useCreateDomainGroup,
  useDeleteDomainGroup,
  useAddDnsRoute,
  useDeleteDnsRoute,
  useNetworkInterfaces,
} from '../hooks';
import type { DomainGroup, DnsRoute } from '../api/types';
import './DnsRoutes.css';

// Icons
const icons = {
  groups: (
    <svg className="dns-routes-section__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <rect x="2" y="3" width="20" height="4" rx="1" />
      <rect x="2" y="10" width="20" height="4" rx="1" />
      <rect x="2" y="17" width="20" height="4" rx="1" />
    </svg>
  ),
  routes: (
    <svg className="dns-routes-section__icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" />
      <path d="M12 8v4l3 3" />
    </svg>
  ),
  edit: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
      <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
    </svg>
  ),
  delete: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <polyline points="3,6 5,6 21,6" />
      <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" />
    </svg>
  ),
  plus: (
    <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2">
      <line x1="12" y1="5" x2="12" y2="19" />
      <line x1="5" y1="12" x2="19" y2="12" />
    </svg>
  ),
};

type TabType = 'groups' | 'routes';

function getTabFromHash(hash: string): TabType {
  const tab = hash.replace('#', '');
  if (tab === 'routes') return 'routes';
  return 'groups';
}

interface GroupFormData {
  name: string;
  description: string;
  domainsText: string;
}

const emptyGroupForm: GroupFormData = { name: '', description: '', domainsText: '' };

interface RouteFormData {
  group: string;
  interface: string;
  comment: string;
}

const emptyRouteForm: RouteFormData = { group: '', interface: '', comment: '' };

export function DnsRoutes() {
  const location = useLocation();
  const navigate = useNavigate();
  const activeTab = getTabFromHash(location.hash);

  const { data: groupsData, isLoading: groupsLoading } = useDomainGroups();
  const { data: routesData, isLoading: routesLoading } = useDnsRoutes();
  const { data: interfacesData } = useNetworkInterfaces();

  const createGroup = useCreateDomainGroup();
  const deleteGroup = useDeleteDomainGroup();
  const addRoute = useAddDnsRoute();
  const deleteRoute = useDeleteDnsRoute();

  // Group modal state
  const [isGroupModalOpen, setIsGroupModalOpen] = useState(false);
  const [editingGroup, setEditingGroup] = useState<DomainGroup | null>(null);
  const [groupForm, setGroupForm] = useState<GroupFormData>(emptyGroupForm);
  const [groupFormError, setGroupFormError] = useState<string | null>(null);

  // Route modal state
  const [isRouteModalOpen, setIsRouteModalOpen] = useState(false);
  const [routeForm, setRouteForm] = useState<RouteFormData>(emptyRouteForm);
  const [routeFormError, setRouteFormError] = useState<string | null>(null);

  useEffect(() => {
    if (!location.hash) {
      navigate('#groups', { replace: true });
    }
  }, [location.hash, navigate]);

  const handleTabChange = (tab: TabType) => navigate(`#${tab}`);

  // Group modal handlers
  const openCreateGroupModal = () => {
    setGroupForm(emptyGroupForm);
    setGroupFormError(null);
    setEditingGroup(null);
    setIsGroupModalOpen(true);
  };

  const openEditGroupModal = (group: DomainGroup) => {
    setGroupForm({
      name: group.name,
      description: group.description || '',
      domainsText: group.domains.join('\n'),
    });
    setGroupFormError(null);
    setEditingGroup(group);
    setIsGroupModalOpen(true);
  };

  const closeGroupModal = () => {
    setIsGroupModalOpen(false);
    setEditingGroup(null);
    setGroupForm(emptyGroupForm);
    setGroupFormError(null);
  };

  const handleGroupSubmit = async () => {
    const { name, description, domainsText } = groupForm;
    const domains = domainsText
      .split('\n')
      .map((d) => d.trim())
      .filter(Boolean);

    if (!name.trim()) {
      setGroupFormError('Name is required');
      return;
    }
    if (!description.trim()) {
      setGroupFormError('Description is required');
      return;
    }
    if (domains.length === 0) {
      setGroupFormError('At least one domain is required');
      return;
    }

    try {
      await createGroup.mutateAsync({ name: name.trim(), description: description.trim(), domains });
      closeGroupModal();
    } catch (err) {
      setGroupFormError(err instanceof Error ? err.message : 'Failed to save group');
    }
  };

  const handleDeleteGroup = async (group: DomainGroup) => {
    try {
      await deleteGroup.mutateAsync(group.name);
    } catch (err) {
      console.error('Failed to delete group:', err);
    }
  };

  // Route modal handlers
  const openCreateRouteModal = () => {
    setRouteForm(emptyRouteForm);
    setRouteFormError(null);
    setIsRouteModalOpen(true);
  };

  const closeRouteModal = () => {
    setIsRouteModalOpen(false);
    setRouteForm(emptyRouteForm);
    setRouteFormError(null);
  };

  const handleRouteSubmit = async () => {
    const { group, interface: iface, comment } = routeForm;
    if (!group) {
      setRouteFormError('Domain group is required');
      return;
    }
    if (!iface) {
      setRouteFormError('Interface is required');
      return;
    }
    try {
      await addRoute.mutateAsync({ group, interface: iface, comment });
      closeRouteModal();
    } catch (err) {
      setRouteFormError(err instanceof Error ? err.message : 'Failed to add route');
    }
  };

  const handleDeleteRoute = async (route: DnsRoute) => {
    try {
      await deleteRoute.mutateAsync(route.index);
    } catch (err) {
      console.error('Failed to delete route:', err);
    }
  };

  // Table columns
  const groupColumns: Column<DomainGroup>[] = [
    {
      key: 'description',
      header: 'Name',
      render: (group) => (
        <div>
          <div className="dns-group-description">{group.description || group.name}</div>
          <div className="dns-group-name">{group.name}</div>
        </div>
      ),
    },
    {
      key: 'domains',
      header: 'Domains',
      render: (group) => (
        <span className="dns-group-domains" title={group.domains.join(', ')}>
          {group.domains.join(', ') || '-'}
        </span>
      ),
    },
    {
      key: 'actions',
      header: '',
      width: '80px',
      align: 'right',
      render: (group) => (
        <div className="dns-actions">
          <button
            className="dns-actions__btn dns-actions__btn--edit"
            onClick={() => openEditGroupModal(group)}
            title="Edit group"
          >
            {icons.edit}
          </button>
          <button
            className="dns-actions__btn dns-actions__btn--delete"
            onClick={() => handleDeleteGroup(group)}
            title="Delete group"
          >
            {icons.delete}
          </button>
        </div>
      ),
    },
  ];

  const routeColumns: Column<DnsRoute>[] = [
    {
      key: 'group',
      header: 'Domain Group',
      render: (route) => <span className="dns-route-group">{route.group}</span>,
    },
    {
      key: 'interface',
      header: 'Interface',
      render: (route) => <span className="dns-route-interface">{route.interface || '-'}</span>,
    },
    {
      key: 'comment',
      header: 'Comment',
      render: (route) => <span className="dns-route-comment">{route.comment || '-'}</span>,
    },
    {
      key: 'actions',
      header: '',
      width: '50px',
      align: 'right',
      render: (route) => (
        <div className="dns-actions">
          <button
            className="dns-actions__btn dns-actions__btn--delete"
            onClick={() => handleDeleteRoute(route)}
            title="Delete route"
          >
            {icons.delete}
          </button>
        </div>
      ),
    },
  ];

  return (
    <div className="dns-routes-page">
      <Header
        title="DNS Routes"
        subtitle={`${groupsData?.count ?? 0} domain groups, ${routesData?.count ?? 0} routes`}
      />

      {/* Stats */}
      <div className="dns-routes-stats">
        <Card className="dns-routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-primary)' }}>
            {groupsData?.count ?? 0}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            Domain Groups
          </div>
        </Card>
        <Card className="dns-routes-stats__card">
          <div style={{ fontSize: 'var(--font-size-2xl)', fontWeight: 700, color: 'var(--color-success)' }}>
            {routesData?.count ?? 0}
          </div>
          <div style={{ fontSize: 'var(--font-size-sm)', color: 'var(--color-text-muted)' }}>
            Active Routes
          </div>
        </Card>
      </div>

      {/* Tabs */}
      <div className="dns-routes-tabbed">
        <div className="dns-routes-tabs">
          <button
            className={`dns-routes-tabs__tab ${activeTab === 'groups' ? 'dns-routes-tabs__tab--active' : ''}`}
            onClick={() => handleTabChange('groups')}
          >
            {icons.groups}
            Domain Groups
          </button>
          <button
            className={`dns-routes-tabs__tab ${activeTab === 'routes' ? 'dns-routes-tabs__tab--active' : ''}`}
            onClick={() => handleTabChange('routes')}
          >
            {icons.routes}
            Routes
          </button>
          <div className="dns-routes-tabs__spacer" />
          {activeTab === 'groups' && (
            <button className="dns-routes-add-btn" onClick={openCreateGroupModal}>
              {icons.plus}
              Create group
            </button>
          )}
          {activeTab === 'routes' && (
            <button className="dns-routes-add-btn" onClick={openCreateRouteModal}>
              {icons.plus}
              Add route
            </button>
          )}
        </div>

        <div className="dns-routes-tab-content">
          {activeTab === 'groups' && (
            <Table
              columns={groupColumns}
              data={groupsData?.domain_groups ?? []}
              keyExtractor={(g) => g.name}
              loading={groupsLoading}
              emptyMessage="No domain groups configured"
            />
          )}
          {activeTab === 'routes' && (
            <Table
              columns={routeColumns}
              data={routesData?.routes ?? []}
              keyExtractor={(r) => r.index}
              loading={routesLoading}
              emptyMessage="No DNS routes configured"
            />
          )}
        </div>
      </div>

      {/* Create/Edit Domain Group Modal */}
      <Modal
        isOpen={isGroupModalOpen}
        onClose={closeGroupModal}
        title={editingGroup ? 'Edit Domain Group' : 'Create Domain Group'}
        footer={
          <>
            <button className="modal-btn modal-btn--secondary" onClick={closeGroupModal}>
              Cancel
            </button>
            <button
              className="modal-btn modal-btn--primary"
              onClick={handleGroupSubmit}
              disabled={createGroup.isPending}
            >
              {createGroup.isPending ? 'Saving...' : 'Save'}
            </button>
          </>
        }
      >
        <div className="modal-form">
          <div className="modal-form__group">
            <label className="modal-form__label">Name (identifier)</label>
            <input
              className="modal-form__input"
              placeholder="e.g., domain-list0"
              value={groupForm.name}
              disabled={!!editingGroup}
              onChange={(e) => setGroupForm((f) => ({ ...f, name: e.target.value }))}
            />
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Description</label>
            <input
              className="modal-form__input"
              placeholder="e.g., YouTube"
              value={groupForm.description}
              onChange={(e) => setGroupForm((f) => ({ ...f, description: e.target.value }))}
            />
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Domains</label>
            <textarea
              className="modal-form__textarea"
              placeholder="youtube.com&#10;googlevideo.com&#10;ytimg.com"
              value={groupForm.domainsText}
              onChange={(e) => setGroupForm((f) => ({ ...f, domainsText: e.target.value }))}
            />
            <div className="modal-form__hint">One domain per line</div>
          </div>
          {groupFormError && <div className="modal-form__error">{groupFormError}</div>}
        </div>
      </Modal>

      {/* Add DNS Route Modal */}
      <Modal
        isOpen={isRouteModalOpen}
        onClose={closeRouteModal}
        title="Add DNS Route"
        footer={
          <>
            <button className="modal-btn modal-btn--secondary" onClick={closeRouteModal}>
              Cancel
            </button>
            <button
              className="modal-btn modal-btn--primary"
              onClick={handleRouteSubmit}
              disabled={addRoute.isPending}
            >
              {addRoute.isPending ? 'Adding...' : 'Add'}
            </button>
          </>
        }
      >
        <div className="modal-form">
          <div className="modal-form__group">
            <label className="modal-form__label">Domain Group</label>
            <select
              className="modal-form__select"
              value={routeForm.group}
              onChange={(e) => setRouteForm((f) => ({ ...f, group: e.target.value }))}
            >
              <option value="">Select domain group...</option>
              {groupsData?.domain_groups.map((g) => (
                <option key={g.name} value={g.name}>
                  {g.description || g.name}
                </option>
              ))}
            </select>
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Interface</label>
            <select
              className="modal-form__select"
              value={routeForm.interface}
              onChange={(e) => setRouteForm((f) => ({ ...f, interface: e.target.value }))}
            >
              <option value="">Select interface...</option>
              {interfacesData?.interfaces.map((iface) => (
                <option key={iface.id} value={iface.id}>
                  {iface.description || iface.id}
                </option>
              ))}
            </select>
          </div>
          <div className="modal-form__group">
            <label className="modal-form__label">Comment (optional)</label>
            <input
              className="modal-form__input"
              placeholder="e.g., Route via VPN"
              value={routeForm.comment}
              onChange={(e) => setRouteForm((f) => ({ ...f, comment: e.target.value }))}
            />
          </div>
          {routeFormError && <div className="modal-form__error">{routeFormError}</div>}
        </div>
      </Modal>
    </div>
  );
}
```

- [ ] **Step 3: Export from pages/index.ts**

Add this line to `frontend/src/pages/index.ts`:

```typescript
export { DnsRoutes } from './DnsRoutes';
```

- [ ] **Step 4: Commit**

```bash
cd /Users/anton/code/apps/keenetic-public && git add frontend/src/pages/DnsRoutes.tsx frontend/src/pages/DnsRoutes.css frontend/src/pages/index.ts && git commit -m "Add DNS Routes page component"
```

---

## Task 5: Wire up routing and navigation

**Files:**
- Modify: `frontend/src/App.tsx`
- Modify: `frontend/src/components/layout/Sidebar.tsx`

- [ ] **Step 1: Add route to App.tsx**

In `frontend/src/App.tsx`, update the import line and add the route:

```typescript
import { Dashboard, DeviceDetail, DeviceLogs, Devices, DnsRoutes, Interfaces, Policies, Routes as RoutesPage, System, SystemLogs } from './pages';
```

Add this `<Route>` after the `/routes` route:

```tsx
<Route path="/dns-routes" element={<DnsRoutes />} />
```

- [ ] **Step 2: Add nav item to Sidebar.tsx**

In `frontend/src/components/layout/Sidebar.tsx`, add the icon to the `icons` object (after `routes`):

```typescript
  dnsRoutes: (
    <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
      <path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2z" />
      <path d="M2 12h20" />
      <path d="M12 2a15.3 15.3 0 0 1 4 10 15.3 15.3 0 0 1-4 10 15.3 15.3 0 0 1-4-10 15.3 15.3 0 0 1 4-10z" />
    </svg>
  ),
```

Add to `navItems` array after the routes entry:

```typescript
  { to: '/dns-routes', label: 'DNS Routes', icon: icons.dnsRoutes },
```

- [ ] **Step 3: Commit**

```bash
cd /Users/anton/code/apps/keenetic-public && git add frontend/src/App.tsx frontend/src/components/layout/Sidebar.tsx && git commit -m "Wire up DNS Routes page to navigation and router"
```

---

## Task 6: Verify TypeScript compiles

- [ ] **Step 1: Run tsc**

```bash
cd /Users/anton/code/apps/keenetic-public/frontend && pnpm tsc --noEmit 2>&1 | head -30
```

Expected: no errors. (`api/index.ts` already does `export * from './types'` so no changes needed there.)

- [ ] **Step 2: Commit plan**

```bash
cd /Users/anton/code/apps/keenetic-public && git add docs/superpowers/plans/2026-03-27-dns-routes.md && git commit -m "Add DNS routes implementation plan"
```
