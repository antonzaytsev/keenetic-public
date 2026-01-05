# Keenetic Gem API Implementation Progress

Implementation status according to [KEENETIC_API.md](./KEENETIC_API.md) specification.

---

## 1. Authentication

- [x] Challenge-response authentication
- [x] Cookie session handling
- [x] MD5 + SHA256 hash calculation

## 2. API Conventions

- [x] GET requests (`client.get`)
- [x] POST requests (`client.post`)
- [x] Batch requests (`client.batch`)
- [x] JSON parsing
- [x] Key normalization (kebab-case → snake_case)
- [x] Boolean normalization

## 3. System

- [x] System Status (`client.system.resources`)
- [x] Firmware & Hardware Info (`client.system.info`)
- [x] System Defaults (`client.system.defaults`)
- [x] License Information (`client.system.license`)

## 4. Devices & Hosts

- [x] List All Devices (`client.devices.all`)
- [x] List Active Devices (`client.devices.active`)
- [x] Find Device (`client.devices.find`)
- [x] Update Device (`client.devices.update`)
- [ ] Delete Device Registration

## 5. Network Interfaces

- [x] List All Interfaces (`client.network.interfaces`)
- [x] Get Interface by ID (`client.network.interface`)
- [x] WAN Status (`client.network.wan_status`)
- [x] LAN Interfaces (`client.network.lan_interfaces`)
- [ ] Interface Statistics
- [ ] Configure Interface

## 6. Internet & WAN

- [x] Internet Status (`client.internet.status`)
- [x] WAN Speed Stats (`client.internet.speed`)
- [ ] Configure WAN Connection

## 7. Wi-Fi

- [x] Wi-Fi Access Points (`client.wifi.access_points`)
- [x] Wi-Fi Clients (`client.wifi.clients`)
- [x] Get Access Point by ID (`client.wifi.access_point`)
- [ ] Configure Wi-Fi
- [ ] Enable/Disable Wi-Fi

## 8. DHCP

- [ ] DHCP Leases
- [ ] Static DHCP Bindings
- [ ] Add Static DHCP Binding
- [ ] Delete Static DHCP Binding

## 9. Routing

- [ ] Routing Table
- [ ] Add Static Route
- [ ] ARP Table

## 10. NAT & Port Forwarding

- [x] List Physical Ports (`client.ports.all`)
- [x] Find Port (`client.ports.find`)
- [ ] List NAT Rules
- [ ] Add Port Forward
- [ ] Delete Port Forward
- [ ] UPnP Mappings

## 11. Firewall

- [ ] Firewall Policies
- [ ] Access Lists
- [ ] Add Firewall Rule

## 12. VPN

- [ ] VPN Server Status
- [ ] VPN Server Clients
- [ ] IPsec Status
- [ ] Configure VPN Server

## 13. USB & Storage

- [ ] USB Devices
- [ ] Storage/Media
- [ ] Safely Eject USB

## 14. DNS

- [ ] DNS Servers
- [ ] DNS Cache
- [ ] DNS Proxy Settings
- [ ] Clear DNS Cache

## 15. Dynamic DNS

- [ ] KeenDNS Status
- [ ] Configure KeenDNS
- [ ] Third-Party DDNS

## 16. Schedules

- [ ] List Schedules
- [ ] Create Schedule
- [ ] Delete Schedule

## 17. Users

- [ ] List Users
- [ ] Create User
- [ ] Delete User

## 18. Logs

- [ ] System Log
- [ ] Filtered Log

## 19. Diagnostics

- [ ] Ping
- [ ] Traceroute
- [ ] DNS Lookup

## 20. System Operations

- [ ] Reboot
- [ ] Save Configuration
- [ ] Factory Reset
- [ ] Check for Updates
- [ ] Apply Firmware Update
- [ ] LED Control
- [ ] Button Configuration

## 21. Components

- [ ] Installed Components
- [ ] Available Components
- [ ] Install Component
- [ ] Remove Component

## 22. Mesh Wi-Fi System

- [ ] Mesh Status
- [ ] Mesh Members

## 23. QoS & Traffic Control

- [ ] Traffic Shaper Status
- [ ] IntelliQoS Settings
- [ ] Traffic Statistics by Host

## 24. IPv6

- [ ] IPv6 Interfaces
- [ ] IPv6 Routes
- [ ] IPv6 Neighbors
