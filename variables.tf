variable "name" {
  description = "Name of the policy definition. Also used as the policy assignment name."
  type        = string

  validation {
    condition     = length(var.name) > 0 && length(var.name) <= 64
    error_message = "The name must be between 1 and 64 characters; Azure rejects longer policy definition names."
  }
}

variable "display_name" {
  description = "Display name of the policy definition."
  type        = string
}

variable "policy_type" {
  description = "Policy type. One of BuiltIn, Custom, or NotSpecified."
  type        = string
  default     = "Custom"

  validation {
    condition     = contains(["BuiltIn", "Custom", "NotSpecified"], var.policy_type)
    error_message = "The policy_type must be one of BuiltIn, Custom, or NotSpecified."
  }
}

variable "mode" {
  description = "Policy resource mode. One of All, Indexed, or a Microsoft.<provider>.Data resource-provider mode."
  type        = string
  default     = "All"

  validation {
    condition     = contains(["all", "indexed"], lower(var.mode)) || can(regex("(?i)^Microsoft\\.[A-Za-z0-9]+\\.Data$", var.mode))
    error_message = "The mode must be All, Indexed, or a resource-provider mode such as Microsoft.KeyVault.Data."
  }
}

variable "description" {
  description = "Description of the policy definition."
  type        = string
  default     = null
}

variable "policy_rule" {
  description = "Policy rule as a JSON-encoded string containing the if/then blocks."
  type        = string

  validation {
    condition     = can(jsondecode(var.policy_rule))
    error_message = "The policy_rule must be a valid JSON-encoded string; use jsonencode({ ... })."
  }

  validation {
    condition     = can(jsondecode(var.policy_rule).if) && can(jsondecode(var.policy_rule).then)
    error_message = "The policy_rule must be a JSON object containing both an \"if\" and a \"then\" block."
  }

  validation {
    condition     = try(length(trimspace(tostring(jsondecode(var.policy_rule).then.effect))) > 0, false)
    error_message = "The policy_rule must set a non-empty \"then.effect\"; without one Azure has nothing to enforce."
  }
}

variable "parameters" {
  description = "Policy parameters as a JSON-encoded string, keyed by parameter name. Null omits parameters."
  type        = string
  default     = null

  validation {
    condition     = var.parameters == null || can(keys(jsondecode(var.parameters)))
    error_message = "The parameters value must be a JSON-encoded object keyed by parameter name."
  }
}

variable "assignment_scope_id" {
  description = "ID of the resource group to assign the policy to. Null creates the definition only, which enforces nothing until it is assigned somewhere."
  type        = string
  default     = null

  validation {
    condition     = var.assignment_scope_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourcegroups/[^/]+$", var.assignment_scope_id))
    error_message = "The assignment_scope_id must be a resource group ID of the form /subscriptions/<sub>/resourceGroups/<rg>; this module assigns at resource group scope only."
  }
}

variable "assignment_parameters" {
  description = "Parameter values for the assignment as a JSON-encoded string, in Azure's {\"name\": {\"value\": ...}} shape. Null omits values."
  type        = string
  default     = null

  validation {
    condition     = var.assignment_parameters == null || can(keys(jsondecode(var.assignment_parameters)))
    error_message = "The assignment_parameters value must be a JSON-encoded object keyed by parameter name."
  }

  validation {
    condition = var.assignment_parameters == null || try(
      alltrue([for spec in values(jsondecode(var.assignment_parameters)) : can(spec.value)]),
      false,
    )
    error_message = "Each assignment parameter must be an object with a \"value\" key, for example {\"tagName\": {\"value\": \"Environment\"}}."
  }
}

variable "location" {
  description = "Azure region for the policy assignment's managed identity. Required whenever identity_type is not None."
  type        = string
  default     = null
}

variable "identity_type" {
  description = "Managed identity for the policy assignment. One of None, SystemAssigned, or UserAssigned. DeployIfNotExists and Modify policies cannot remediate without one."
  type        = string
  default     = "None"

  validation {
    condition     = contains(["None", "SystemAssigned", "UserAssigned"], var.identity_type)
    error_message = "The identity_type must be one of None, SystemAssigned, or UserAssigned."
  }
}

variable "identity_ids" {
  description = "User assigned identity IDs to attach to the assignment. Only used when identity_type is UserAssigned."
  type        = list(string)
  default     = []
}

variable "enforce" {
  description = "Whether the assignment enforces the policy effect. Setting this to false puts the assignment in DoNotEnforce mode, where it reports compliance but never blocks or remediates anything."
  type        = bool
  default     = true
}
