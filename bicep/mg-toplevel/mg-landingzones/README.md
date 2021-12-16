# 1st level: Landing Zones

This management group contains management groups for online and corp landing zones. You would want different policies for your online subscriptions and your corp subscriptions, and this management group topology enables differentiation for many subscriptions.

- Tenant Root Management Group
  - TreyResearch
    - Decommissioned
    - Sandboxes
    - Landing Zones **<-- This Management Group**
      - Online
      - Corp
    - Platform