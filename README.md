# terraform-azurerm-policy

Terraform module that manages an [Azure Policy](https://azure.microsoft.com/products/azure-policy)
definition and, optionally, assigns it to a resource group. The policy rule and
parameters are supplied as JSON-encoded strings so any custom governance rule
can be expressed.

## Usage

```hcl
module "policy" {
  source = "github.com/cybercapybara/terraform-azurerm-policy"

  name         = "require-environment-tag"
  display_name = "Require an Environment tag on resources"

  policy_rule = jsonencode({
    if   = { field = "tags['Environment']", exists = "false" }
    then = { effect = "deny" }
  })

  assignment_scope_id = "/subscriptions/xxxx/resourceGroups/prod-rg"
}
```

A runnable example lives in [`examples/basic`](examples/basic).

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

## Inputs

| Name                    | Description                                                          | Type     | Default    | Required |
|-------------------------|----------------------------------------------------------------------|----------|------------|:--------:|
| `name`                  | Name of the policy definition.                                       | `string` | n/a        |   yes    |
| `display_name`          | Display name of the policy definition.                               | `string` | n/a        |   yes    |
| `policy_type`           | Policy type: BuiltIn, Custom, or NotSpecified.                       | `string` | `"Custom"` |    no    |
| `mode`                  | Policy resource mode.                                                | `string` | `"All"`    |    no    |
| `description`           | Description of the policy definition.                                | `string` | `null`     |    no    |
| `policy_rule`           | Policy rule as a JSON-encoded string.                                | `string` | n/a        |   yes    |
| `parameters`            | Policy parameters as a JSON-encoded string.                          | `string` | `null`     |    no    |
| `assignment_scope_id`   | ID of the resource group to assign the policy to.                    | `string` | `null`     |    no    |
| `assignment_parameters` | Parameter values for the assignment as a JSON-encoded string.        | `string` | `null`     |    no    |

## Outputs

| Name            | Description                                          |
|-----------------|------------------------------------------------------|
| `id`            | ID of the policy definition.                         |
| `name`          | Name of the policy definition.                       |
| `assignment_id` | ID of the resource group policy assignment, if any.  |

## License

[MIT](LICENSE)
