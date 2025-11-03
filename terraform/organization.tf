/*
  organization.tf (disabled)

  The full AWS Organizations bootstrap is intentionally disabled in this
  workspace by default to avoid cross-account actions and the need to
  assume a root management role. If you want to enable organization
  provisioning, reintroduce these resources behind a variable guard
  (e.g. var.manage_organization) and provide a proper root_account_id
  and credentials with permission to assume OrganizationAccountAccessRole.

*/