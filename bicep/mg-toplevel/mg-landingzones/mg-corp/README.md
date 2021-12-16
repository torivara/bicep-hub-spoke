# 2nd level: Corp landing zones

This management group contains subscriptions for corp landing zones. Here you can set restrictions for resources that require access to your corporate network. Extra security is needed when resources have access on-premises. Maybe different endpoint security, maybe more strict NSG configs, might be need for restricting all outbound traffic?

- Tenant Root Management Group
  - TreyResearch
    - Decommissioned
    - Sandboxes
    - Landing Zones
      - Online
      - Corp **<-- This Management Group**
    - Platform
