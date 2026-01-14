# Request Flow: Public Internet to App Service

This document details the network traffic flow from the public internet to the Azure App Service, as defined in the Terraform configuration.

## High-Level Overview

The architecture is distributed across **two Virtual Networks** connected via **VPN Gateways (VNet-to-VNet)**. This simulates a cross-premises or isolated connectivity scenario where the ingress controller and workload are separated.

The **Application Gateway** serves as the single entry point for public traffic. The **App Service** is completely isolated from the public internet and is only accessible via a **Private Endpoint** in the backend network.

**Flow Summary:**
`User` -> `App Gateway (Public IP)` -> `VPN Gateway (VNet-to-VNet Tunnel)` -> `Private Link` -> `App Service`

---

## Step-by-Step Request Flow

### 1. Public Internet to Application Gateway
*   **Source**: Public Internet client (browser, API client).
*   **Destination**: Azure Application Gateway Public IP.
*   **Protocol/Port**: HTTP (80) or HTTPS (443).
*   **Mechanism**:
    *   The Application Gateway has a Standard SKU Public IP assigned.
    *   **Network Security Group (NSG)**: The `nsg-appgw` applied to the `snet-appgw` subnet explicitly allows inbound traffic on ports 80 and 443 from `*` (Any).

### 2. Application Gateway Processing
*   **Listener**:
    *   **Port 80**: A listener captures HTTP traffic and immediately redirects it to HTTPS (Port 443) using a permanent redirect configuration.
    *   **Port 443**: A listener captures HTTPS traffic and terminates the SSL connection using the configured SSL certificate.
*   **Routing**:
    *   The request is processed by the `https-settings` backend HTTP settings.
    *   **Backend Pool**: The backend pool is configured with the FQDN of the App Service (e.g., `app-workload-dev-xyz.azurewebsites.net`).

### 3. DNS Resolution (Critical Step)
*   **Context**: The Application Gateway resides in the `vnet-appgw` Virtual Network, while the App Service resides in the `vnet-backend` Virtual Network.
*   **Mechanism**:
    *   The **Private DNS Zone** (`privatelink.azurewebsites.net`) is maintained in the project but is **linked to both Virtual Networks**.
    *   When the Application Gateway tries to resolve the App Service's FQDN, the Private DNS Zone linked to `vnet-appgw` intercepts the request.
    *   Instead of returning the public IP of the App Service, it returns the **Private IP** address associated with the App Service's Private Endpoint (located in `snet-private-endpoints` in `vnet-backend`).

### 4. Application Gateway to App Service
*   **Source**: Application Gateway instance (Private IP in `snet-appgw` in `vnet-appgw`).
*   **Destination**: App Service Private Endpoint (Private IP in `snet-private-endpoints` in `vnet-backend`).
*   **Protocol/Port**: HTTPS (443).
*   **Mechanism**:
    *   The Application Gateway initiates a new connection to the backend Private IP.
    *   **Routing**: Traffic is routed via the **VPN Gateway** in `vnet-appgw`, through the **IPsec VNet-to-VNet tunnel**, to the **VPN Gateway** in `vnet-backend`.
    *   From `vnet-backend`, traffic reaches the Private Endpoint.
    *   Traffic flows entirely within the Azure Virtual Network backbone (encrypted via VPN).
    *   **App Service Configuration**: The App Service has `public_network_access_enabled = false`, ensuring it rejects any traffic not coming through the Private Endpoint.
    *   **Host Header**: The `pick_host_name_from_backend_address = true` setting ensures the Host header matches the App Service FQDN, which is required for the App Service to accept the request.

---

## Component Configuration Details

### Application Gateway
*   **Subnet**: `snet-appgw`
*   **Public Access**: Yes (Static Public IP).
*   **Backend Communication**: Uses the backend's FQDN, which resolves to a private IP.

### App Service
*   **Subnet Integration**: `snet-app-integration` (Used for *outbound* traffic from the app to other Azure resources).
*   **Public Access**: **Disabled**.
*   **Private Access**: Enabled via Private Endpoint in `snet-private-endpoints`.

### Network Security Groups (NSG)
*   **`nsg-appgw`**:
    *   Allows Inbound 80/443 from Internet.
    *   Allows Inbound 65200-65535 for Gateway Manager (Azure Infrastructure).
*   **`nsg-app`**:
    *   Applied to `snet-app-integration`.
    *   *Note*: This NSG primarily filters traffic for the integration subnet. Since inbound traffic arrives via the Private Endpoint (which bypasses this subnet's NSG by default), the rules here are secondary to the Private Endpoint restriction.

### Private DNS
*   **Zone**: `privatelink.azurewebsites.net`
*   **Link**: Linked to the main Virtual Network.
*   **Record**: Maps the App Service name to the Private Endpoint IP.
