// Device types
export interface DeviceInterface {
  id?: string;
  name?: string;
  description?: string;
}

export interface Device {
  mac: string;
  name: string | null;
  hostname: string | null;
  ip: string | null;
  static_ip: string | null;
  interface: string | DeviceInterface | null;
  via: string | null;
  wifi_ap: string | null;
  mws_cid: string | null;
  active: boolean;
  registered: boolean;
  access: string | null;
  schedule: string | null;
  rxbytes: number | null;
  txbytes: number | null;
  uptime: number | null;
  first_seen: string | null;
  last_seen: string | null;
  link: string | null;
  // Wi-Fi association data (only for active Wi-Fi clients)
  rssi: number | null;
  txrate: number | null;
  rxrate: number | null;
  wifi_mode: string | null;
  wifi_ht: boolean | null;
  wifi_vht: boolean | null;
  wifi_he: boolean | null;
}

export interface DevicesResponse {
  devices: Device[];
  count: number;
  timestamp: string;
}

export interface DeviceResponse {
  device: Device;
  timestamp: string;
}

// System types
export interface CpuInfo {
  load_percent: number;
}

export interface MemoryInfo {
  total: number;
  free: number;
  used: number;
  buffers: number;
  cached: number;
  used_percent: number;
}

export interface SwapInfo {
  total: number;
  free: number;
  used: number;
  used_percent: number;
}

export interface SystemResources {
  cpu: CpuInfo | null;
  memory: MemoryInfo | null;
  swap: SwapInfo | null;
  uptime: number | null;
}

export interface ResourcesResponse {
  resources: SystemResources;
  timestamp: string;
}

export interface SystemInfo {
  model: string | null;
  device: string | null;
  manufacturer: string | null;
  vendor: string | null;
  hw_version: string | null;
  hw_id: string | null;
  firmware: string | null;
  firmware_version: string | null;
  ndm_version: string | null;
  arch: string | null;
  ndw_version: string | null;
  components: string[] | null;
  sandbox: string | null;
}

export interface SystemInfoResponse {
  info: SystemInfo;
  timestamp: string;
}

// Network types
export interface NetworkInterface {
  id: string;
  description: string | null;
  type: string | null;
  mac: string | null;
  mtu: number | null;
  state: string | null;
  link: string | null;
  connected: boolean | null;
  address: string | null;
  mask: string | null;
  gateway: string | null;
  defaultgw: boolean | null;
  uptime: number | null;
  rxbytes: number | null;
  txbytes: number | null;
  rxpackets: number | null;
  txpackets: number | null;
  last_change: string | null;
  speed: number | null;
  duplex: string | null;
  security: string | null;
  global: boolean | null;
}

export interface InterfacesResponse {
  interfaces: NetworkInterface[];
  count: number;
  timestamp: string;
}

// WiFi types
export interface AccessPoint {
  id: string;
  description: string | null;
  type: string | null;
  ssid: string | null;
  mac: string | null;
  state: string | null;
  link: string | null;
  connected: boolean | null;
  channel: number | null;
  band: string | null;
  security: string | null;
  encryption: string | null;
  clients_count: number | null;
  txpower: number | null;
  uptime: number | null;
}

export interface AccessPointsResponse {
  access_points: AccessPoint[];
  count: number;
  timestamp: string;
}

// Mesh Wi-Fi System types
export interface MeshMember {
  id: string;
  mac: string | null;
  name: string | null;
  model: string | null;
  hw_id: string | null;
  hw_version: string | null;
  mode: 'controller' | 'extender' | string | null;
  via: string | null;
  ip: string | null;
  version: string | null;
  online: boolean;
  uptime: number | null;
  clients_count: number | null;
  connection_speed: string | null;
  alert: boolean | null;
}

export interface MeshMembersResponse {
  members: MeshMember[];
  count: number;
  timestamp: string;
}

// Internet status types
export interface InternetStatus {
  connected: boolean;
  gateway: string | null;
  dns: string[];
  checked: string | null;
  checking: boolean | null;
}

export interface InternetStatusResponse {
  status: InternetStatus;
  timestamp: string;
}

export interface InternetSpeed {
  interface: string | null;
  rxbytes: number | null;
  txbytes: number | null;
  rxpackets: number | null;
  txpackets: number | null;
  uptime: number | null;
}

export interface InternetSpeedResponse {
  speed: InternetSpeed | null;
  timestamp: string;
}

// Physical ports types
export interface Port {
  id: string;
  port: number | null;
  type: 'gigabit' | 'fast' | 'sfp' | 'usb' | 'unknown';
  link: boolean;
  speed: number | null;
  duplex: string | null;
  rxbytes: number | null;
  txbytes: number | null;
  rxpackets: number | null;
  txpackets: number | null;
  rxerrors: number | null;
  txerrors: number | null;
  media: string | null;
}

export interface PortsResponse {
  ports: Port[];
  count: number;
  timestamp: string;
}

// Health check
export interface HealthResponse {
  status: string;
  timestamp: string;
}

// Policy types
export interface Policy {
  id: string;
  description: string;
  name: string;
  interfaces: string[];
  interface_count: number;
}

export interface PoliciesResponse {
  policies: Policy[];
  device_assignments: Record<string, string>;
  count: number;
  timestamp: string;
}

export interface PolicyResponse {
  policy: Policy;
  timestamp: string;
}

// Routing types
export interface Route {
  destination: string | null;
  mask: string | null;
  gateway: string | null;
  interface: string | null;
  metric: number | null;
  flags: string | null;
  auto: boolean | null;
}

export interface RoutesResponse {
  routes: Route[];
  count: number;
  timestamp: string;
}

export interface ArpEntry {
  ip: string | null;
  mac: string | null;
  interface: string | null;
  state: string | null;
}

export interface ArpResponse {
  arp_table: ArpEntry[];
  count: number;
  timestamp: string;
}

// API Error
export interface ApiError {
  error: string;
  message: string;
  timestamp: string;
}

