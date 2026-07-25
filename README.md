# terraform-azurerm-policy

Terraform module that manages an [Azure Policy](https://azure.microsoft.com/products/azure-policy)
definition and, optionally, assigns it to a resource group. The policy rule and
parameters are supplied as JSON-encoded strings so any custom governance rule
can be expressed.

## Usage

```hcl
module "policy" {
  source = "github.com/moveeeax/terraform-azurerm-policy"

  name         = "require-environment-tag"
  display_name = "Require an Environment tag on resources"

  policy_rule = jsonencode({
    if   = { field = "tags['Environment']", exists = "false" }
    then = { effect = "deny" }
  })

  assignment_scope_id = "/subscriptions/xxxx/resourceGroups/prod-rg"
}
```

Runnable examples live in [`examples/basic`](examples/basic) (a `Deny` policy)
and [`examples/deploy-if-not-exists`](examples/deploy-if-not-exists) (a
remediating policy with a managed identity).

## Policies that apply cleanly and enforce nothing

Azure accepts several policy shapes that look successful in `terraform apply`
and then govern nothing at all. The module fails the plan, or warns, for each of
these rather than letting them through silently:

| Situation | What the module does |
|-----------|----------------------|
| `policy_rule` is not valid JSON, or has no `if`/`then`, or has an empty `then.effect` | plan fails on `var.policy_rule` |
| The effect resolves to `Disabled` — including via a parameter's `defaultValue` | plan warns via a `check` block |
| The effect is not a recognised Azure Policy effect | plan warns via a `check` block |
| A `DeployIfNotExists` or `Modify` policy is assigned without a managed identity, or with an identity but no `location` | plan fails on the assignment; Azure would otherwise create an assignment that can never remediate |
| A parameter is declared with no `defaultValue` and given no assignment value | plan fails on the assignment; Azure would reject it |
| `assignment_parameters` uses `{"tagName": "Environment"}` instead of Azure's `{"tagName": {"value": "Environment"}}` | plan fails on `var.assignment_parameters` |
| `assignment_scope_id` is a subscription or management group ID rather than a resource group ID | plan fails on `var.assignment_scope_id` |

Two cases the module deliberately leaves to you, because both are legitimate:

- **`assignment_scope_id = null`** (the default) creates the definition only.
  A definition that is never assigned enforces nothing — assign it here or
  somewhere else.
- **`enforce = false`** puts the assignment in Azure's `DoNotEnforce` mode,
  where compliance is reported but nothing is blocked or remediated. The
  default is `true`.

`effective_effect` is exported so you can assert on the effect that will
actually take hold, with any `[parameters('...')]` reference resolved through
the assignment values and parameter defaults.

## Requirements

| Name      | Version  |
|-----------|----------|
| terraform | >= 1.5   |
| azurerm   | >= 3.0   |

The `>= 3.0` floor is verified: the full test suite passes against azurerm
`3.0.0`, `4.0.0` and `4.81.0`. Running `terraform test` additionally needs
Terraform or OpenTofu >= 1.7 for `mock_provider`; that is a test-only
requirement and does not apply to consumers of the module.

## Inputs

| Name                    | Description                                                                                                  | Type           | Default    | Required |
|-------------------------|--------------------------------------------------------------------------------------------------------------|----------------|------------|:--------:|
| `name`                  | Name of the policy definition (1–64 chars). Also used as the assignment name.                                 | `string`       | n/a        |   yes    |
| `display_name`          | Display name of the policy definition.                                                                        | `string`       | n/a        |   yes    |
| `policy_type`           | Policy type: `BuiltIn`, `Custom`, or `NotSpecified`.                                                          | `string`       | `"Custom"` |    no    |
| `mode`                  | Policy resource mode: `All`, `Indexed`, or `Microsoft.<provider>.Data`.                                       | `string`       | `"All"`    |    no    |
| `description`           | Description of the policy definition.                                                                         | `string`       | `null`     |    no    |
| `policy_rule`           | Policy rule as a JSON-encoded string with `if` and `then` blocks.                                             | `string`       | n/a        |   yes    |
| `parameters`            | Policy parameters as a JSON-encoded object keyed by parameter name.                                           | `string`       | `null`     |    no    |
| `assignment_scope_id`   | Resource group ID to assign the policy to. `null` creates the definition only.                                | `string`       | `null`     |    no    |
| `assignment_parameters` | Assignment parameter values as JSON, in Azure's `{"name": {"value": ...}}` shape.                             | `string`       | `null`     |    no    |
| `location`              | Region for the assignment's managed identity. Required whenever `identity_type` is not `None`.                | `string`       | `null`     |    no    |
| `identity_type`         | Assignment managed identity: `None`, `SystemAssigned`, or `UserAssigned`. Needed by DeployIfNotExists/Modify. | `string`       | `"None"`   |    no    |
| `identity_ids`          | User assigned identity IDs, used only when `identity_type` is `UserAssigned`.                                 | `list(string)` | `[]`       |    no    |
| `enforce`               | Whether the assignment enforces the effect. `false` means report-only (`DoNotEnforce`).                       | `bool`         | `true`     |    no    |

## Outputs

| Name                               | Description                                                                                       |
|------------------------------------|---------------------------------------------------------------------------------------------------|
| `id`                               | ID of the policy definition.                                                                       |
| `name`                             | Name of the policy definition.                                                                     |
| `assignment_id`                    | ID of the resource group policy assignment, if any.                                                |
| `assignment_identity_principal_id` | Principal ID of the assignment's managed identity. Grant it the roles a remediating policy needs.   |
| `effective_effect`                 | The effect the policy will actually apply, with parameter references resolved.                     |

## Development

```sh
terraform fmt -recursive
terraform init -backend=false && terraform validate
terraform test          # mocked provider, no Azure credentials required
tflint --recursive
```

## License

[MIT](LICENSE)
