# GitHub Workflow - Step Function Executor

This repository contains GitHub Actions workflows for managing AWS Step Function executions with enhanced GitHub context tracking.

## Overview

The Step Function Executor system provides a standardized way to trigger AWS Step Functions with descriptive execution names and comprehensive GitHub context information. This helps developers quickly identify which Step Function execution was triggered by which change.

## Key Features

- **Descriptive Execution Names**: Execution names include repository, commit SHA, PR number (if applicable), and author
- **GitHub Context Integration**: Automatically includes GitHub context in Step Function inputs
- **Character Limit Management**: Handles AWS Step Function execution name length limitations (256 characters)
- **Flexible Configuration**: Supports both with and without GitHub context
- **Reusable Workflow**: Can be called from any other workflow

## Files

### Core Workflow
- `.github/workflows/step-function-executor.yaml` - Reusable workflow for executing Step Functions

### Example Usage
- `.github/workflows/trigger-smoke-test.yaml` - Updated smoke test workflow using the executor
- `.github/workflows/example-step-function-usage.yaml` - Comprehensive examples of different usage patterns

## Usage

### Basic Usage

```yaml
- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:MyStateMachine"
    execution_name_prefix: "myapp"
    input_data: |
      {
        "environment": "prod",
        "data": "example"
      }
    include_github_context: "true"
```

### Parameters

| Parameter | Required | Description |
|-----------|----------|-------------|
| `state_machine_arn` | Yes | The ARN of the Step Function state machine |
| `execution_name_prefix` | Yes | Prefix for the execution name |
| `input_data` | Yes | JSON string containing input data |
| `include_github_context` | No | Whether to include GitHub context (default: "true") |
| `max_execution_name_length` | No | Maximum execution name length (default: "256") |

### Execution Name Format

When `include_github_context` is enabled, execution names follow this format:

- **For Pull Requests**: `{prefix}-{repo}-{short_sha}-pr{number}-{actor}-{uuid}`
- **For Other Events**: `{prefix}-{repo}-{short_sha}-{actor}-{uuid}`

Example: `smoketest-myapp-a1b2c3d-pr123-john.doe-550e8400`

### GitHub Context in Inputs

When `include_github_context` is enabled, the following context is automatically added to the Step Function input:

```json
{
  "your_input_data": "...",
  "github_context": {
    "repository": "owner/repo",
    "ref": "refs/heads/main",
    "sha": "a1b2c3d4e5f6...",
    "short_sha": "a1b2c3d",
    "actor": "john.doe",
    "run_id": "1234567890",
    "run_number": "42",
    "workflow": "My Workflow",
    "job": "my-job",
    "event_name": "push",
    "event_ref": "refs/heads/main",
    "event_head_ref": null,
    "event_base_ref": null,
    "event_pull_request_number": null
  }
}
```

## Examples

### Example 1: Basic Execution with GitHub Context

```yaml
- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:BasicStateMachine"
    execution_name_prefix: "basic"
    input_data: |
      {
        "environment": "dev",
        "message": "Basic execution"
      }
    include_github_context: "true"
```

### Example 2: Custom Input Without GitHub Context

```yaml
- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:CustomStateMachine"
    execution_name_prefix: "custom"
    input_data: |
      {
        "custom_field": "example_value",
        "timestamp": "2024-01-01T00:00:00Z"
      }
    include_github_context: "false"
```

### Example 3: Complex Input with Dynamic Data

```yaml
- name: Prepare complex input
  id: prepare_input
  run: |
    COMPLEX_INPUT=$(jq -n \
      --arg env "${{ github.event.inputs.environment || 'dev' }}" \
      --arg sha "${{ github.sha }}" \
      '{
        environment: $env,
        deployment_info: {
          commit_sha: $sha,
          timestamp: now | todateiso8601
        }
      }'
    )
    echo "complex_input=$COMPLEX_INPUT" >> $GITHUB_OUTPUT

- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "arn:aws:states:us-east-1:123456789012:stateMachine:ComplexStateMachine"
    execution_name_prefix: "complex"
    input_data: ${{ steps.prepare_input.outputs.complex_input }}
    include_github_context: "true"
```

## Outputs

The workflow provides the following outputs:

- `execution_arn`: The ARN of the started Step Function execution
- `execution_name`: The name of the execution

These can be used in subsequent steps or jobs:

```yaml
jobs:
  my-job:
    outputs:
      execution_arn: ${{ jobs.execute-step-function.outputs.execution_arn }}
      execution_name: ${{ jobs.execute-step-function.outputs.execution_name }}
```

## Character Limit Management

AWS Step Functions have a 256-character limit for execution names. The workflow automatically:

1. Calculates available space (256 - 9 characters for 8-character UUID)
2. Truncates the execution name if necessary
3. Adds a UUID for uniqueness

## Best Practices

1. **Use Descriptive Prefixes**: Choose prefixes that clearly identify the purpose (e.g., "smoketest", "deploy", "validate")
2. **Include GitHub Context**: Enable `include_github_context` for better traceability
3. **Handle Outputs**: Capture execution ARNs for downstream processing
4. **Test Execution Names**: Verify your execution names don't exceed limits in your environment
5. **Use Consistent Naming**: Follow a consistent pattern across your workflows

## Troubleshooting

### Common Issues

1. **Execution Name Too Long**: The workflow automatically truncates names, but ensure your prefix is reasonable
2. **Invalid JSON Input**: Ensure your `input_data` is valid JSON
3. **Missing Permissions**: Ensure the workflow has proper AWS permissions to execute Step Functions

### Debugging

The workflow includes detailed logging and will display:
- The generated execution name
- The input data being sent
- The execution ARN upon successful start
- A summary in the GitHub Actions step summary

## Migration from Direct Step Function Calls

To migrate from direct `aws stepfunctions start-execution` calls:

1. Replace the direct AWS CLI call with the reusable workflow
2. Move your input data to the `input_data` parameter
3. Set an appropriate `execution_name_prefix`
4. Enable `include_github_context` for better traceability

Example migration:

**Before:**
```yaml
- name: Trigger Step Function
  run: |
    aws stepfunctions start-execution \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --input "$INPUT_JSON"
```

**After:**
```yaml
- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "$STATE_MACHINE_ARN"
    execution_name_prefix: "myapp"
    input_data: "$INPUT_JSON"
    include_github_context: "true"
```