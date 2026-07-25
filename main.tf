locals {
  # Decoded views of the JSON-string inputs. `try` keeps these evaluable even
  # when a value is invalid: the variable validations report the real problem.
  policy_rule_object         = try(jsondecode(var.policy_rule), {})
  declared_parameters        = try(jsondecode(var.parameters), {})
  assignment_parameter_input = try(jsondecode(var.assignment_parameters), {})

  # The literal contents of `then.effect`, which may be a parameter reference
  # such as "[parameters('effect')]" rather than an effect name.
  raw_effect       = trimspace(try(tostring(local.policy_rule_object.then.effect), ""))
  effect_parameter = try(regex("(?i)^\\[parameters\\('([^']+)'\\)\\]$", local.raw_effect)[0], null)

  # When the effect is parameterised, the value that actually takes hold is the
  # assignment value if supplied, otherwise the parameter's defaultValue.
  resolved_effect_value = try(
    local.assignment_parameter_input[local.effect_parameter].value,
    local.declared_parameters[local.effect_parameter].defaultValue,
    "",
  )

  effective_effect = lower(
    local.effect_parameter == null
    ? local.raw_effect
    : trimspace(try(tostring(local.resolved_effect_value), ""))
  )

  # Effects whose remediation runs as the assignment's managed identity. Azure
  # rejects an assignment for these unless it carries an identity and a location.
  identity_backed_effects = ["deployifnotexists", "modify"]
  requires_identity       = contains(local.identity_backed_effects, local.effective_effect)

  known_effects = [
    "addtonetworkgroup",
    "append",
    "audit",
    "auditifnotexists",
    "deny",
    "denyaction",
    "deployifnotexists",
    "disabled",
    "manual",
    "modify",
  ]

  # Parameters declared without a defaultValue must be given a value at
  # assignment time or the assignment is rejected.
  required_parameter_names = [
    for name, spec in local.declared_parameters : name if !can(spec.defaultValue)
  ]
  missing_assignment_parameters = [
    for name in local.required_parameter_names : name
    if !can(local.assignment_parameter_input[name].value)
  ]
}

resource "azurerm_policy_definition" "this" {
  name         = var.name
  display_name = var.display_name
  policy_type  = var.policy_type
  mode         = var.mode
  description  = var.description

  policy_rule = var.policy_rule
  parameters  = var.parameters
}

resource "azurerm_resource_group_policy_assignment" "this" {
  count = var.assignment_scope_id == null ? 0 : 1

  name                 = var.name
  display_name         = var.display_name
  resource_group_id    = var.assignment_scope_id
  policy_definition_id = azurerm_policy_definition.this.id
  parameters           = var.assignment_parameters
  location             = var.location
  enforce              = var.enforce

  dynamic "identity" {
    for_each = var.identity_type == "None" ? [] : [var.identity_type]

    content {
      type         = identity.value
      identity_ids = identity.value == "UserAssigned" ? var.identity_ids : null
    }
  }

  lifecycle {
    precondition {
      condition     = !local.requires_identity || var.identity_type != "None"
      error_message = "Policy effect \"${local.effective_effect}\" is remediated by a managed identity, so the assignment needs one. Set identity_type to \"SystemAssigned\" or \"UserAssigned\"."
    }

    precondition {
      condition     = var.identity_type == "None" || try(trimspace(var.location), "") != ""
      error_message = "A policy assignment with a managed identity must also set location; Azure rejects the assignment otherwise."
    }

    precondition {
      condition     = var.identity_type != "UserAssigned" || length(var.identity_ids) > 0
      error_message = "identity_type = \"UserAssigned\" requires at least one user assigned identity ID in identity_ids."
    }

    precondition {
      condition     = length(local.missing_assignment_parameters) == 0
      error_message = "These policy parameters have no defaultValue and no assignment value, so Azure would reject the assignment: ${join(", ", local.missing_assignment_parameters)}."
    }
  }
}

# Warn (rather than fail) about policies that apply cleanly and enforce nothing.
# Both cases are legitimate on purpose, but almost never on accident.
check "policy_effect_is_enforcing" {
  assert {
    condition     = local.effective_effect != "disabled"
    error_message = "Policy \"${var.name}\" resolves to effect \"disabled\", so it will be created and evaluated but will never act on anything."
  }
}

check "policy_effect_is_recognised" {
  assert {
    condition     = local.effective_effect == "" || contains(local.known_effects, local.effective_effect)
    error_message = "Policy \"${var.name}\" uses effect \"${local.effective_effect}\", which is not a known Azure Policy effect. Azure rejects unknown effects."
  }
}
