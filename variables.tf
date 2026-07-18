variable "name" {
  description = "Name of the policy definition."
  type        = string
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
  description = "Policy resource mode. One of All, Indexed, or a Microsoft.<provider> resource-provider mode."
  type        = string
  default     = "All"
}

variable "description" {
  description = "Description of the policy definition."
  type        = string
  default     = null
}

variable "policy_rule" {
  description = "Policy rule as a JSON-encoded string containing the if/then blocks."
  type        = string
}

variable "parameters" {
  description = "Policy parameters as a JSON-encoded string. Null omits parameters."
  type        = string
  default     = null
}

variable "assignment_scope_id" {
  description = "ID of the resource group to assign the policy to. Null disables assignment."
  type        = string
  default     = null
}

variable "assignment_parameters" {
  description = "Parameter values for the assignment as a JSON-encoded string. Null omits values."
  type        = string
  default     = null
}
