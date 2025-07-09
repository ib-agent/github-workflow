# Step Function Executor Integration Guide

This guide explains how to integrate the Step Function Executor into your existing GitHub Actions workflows.

## Quick Migration

### Step 1: Identify Direct Step Function Calls

Look for patterns like this in your workflows:

```yaml
- name: Trigger Step Function
  run: |
    aws stepfunctions start-execution \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --input "$INPUT_JSON"
```

### Step 2: Replace with Reusable Workflow

Replace the direct AWS CLI call with:

```yaml
- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "$STATE_MACHINE_ARN"
    execution_name_prefix: "your-prefix"
    input_data: "$INPUT_JSON"
    include_github_context: "true"
```

## Migration Examples

### Example 1: Simple Smoke Test

**Before:**
```yaml
- name: Trigger Smoke Test
  run: |
    INPUT_JSON='{
      "environment": "${{ inputs.environment }}",
      "company_list": ["company1", "company2"]
    }'
    EXEC_NAME="smoketest-${{ inputs.environment }}-${{ github.sha }}"
    
    aws stepfunctions start-execution \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --name "$EXEC_NAME" \
      --input "$INPUT_JSON"
```

**After:**
```yaml
- name: Execute Smoke Test
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "$STATE_MACHINE_ARN"
    execution_name_prefix: "smoketest"
    input_data: |
      {
        "environment": "${{ inputs.environment }}",
        "company_list": ["company1", "company2"]
      }
    include_github_context: "true"
```

### Example 2: Complex Input with Dynamic Data

**Before:**
```yaml
- name: Prepare input data
  id: prepare_input
  run: |
    INPUT_JSON=$(jq -n \
      --arg env "${{ inputs.environment }}" \
      --arg sha "${{ github.sha }}" \
      '{
        environment: $env,
        commit_sha: $sha,
        timestamp: now | todateiso8601
      }'
    )
    echo "input_json=$INPUT_JSON" >> $GITHUB_OUTPUT

- name: Trigger Step Function
  run: |
    aws stepfunctions start-execution \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --input "${{ steps.prepare_input.outputs.input_json }}"
```

**After:**
```yaml
- name: Prepare input data
  id: prepare_input
  run: |
    INPUT_JSON=$(jq -n \
      --arg env "${{ inputs.environment }}" \
      --arg sha "${{ github.sha }}" \
      '{
        environment: $env,
        commit_sha: $sha,
        timestamp: now | todateiso8601
      }'
    )
    echo "input_json=$INPUT_JSON" >> $GITHUB_OUTPUT

- name: Execute Step Function
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "$STATE_MACHINE_ARN"
    execution_name_prefix: "deploy"
    input_data: ${{ steps.prepare_input.outputs.input_json }}
    include_github_context: "true"
```

### Example 3: Conditional Execution

**Before:**
```yaml
- name: Trigger Step Function
  if: github.event_name == 'pull_request'
  run: |
    aws stepfunctions start-execution \
      --state-machine-arn "$STATE_MACHINE_ARN" \
      --input "$INPUT_JSON"
```

**After:**
```yaml
- name: Execute Step Function
  if: github.event_name == 'pull_request'
  uses: ./.github/workflows/step-function-executor.yaml
  with:
    state_machine_arn: "$STATE_MACHINE_ARN"
    execution_name_prefix: "pr-validation"
    input_data: "$INPUT_JSON"
    include_github_context: "true"
```

## Benefits of Migration

### 1. Better Execution Names
- **Before**: `smoketest-dev-a1b2c3d4e5f6`
- **After**: `smoketest-myapp-a1b2c3d-pr123-john.doe-550e8400`

### 2. GitHub Context in Inputs
Your Step Function will automatically receive GitHub context:

```json
{
  "your_data": "...",
  "github_context": {
    "repository": "owner/repo",
    "sha": "a1b2c3d4e5f6...",
    "actor": "john.doe",
    "run_id": "1234567890",
    "event_name": "pull_request",
    "event_pull_request_number": "123"
  }
}
```

### 3. Automatic Character Limit Management
The workflow automatically handles AWS Step Function execution name length limitations.

### 4. Better Error Handling
Enhanced logging and error reporting for debugging.

## Testing Your Migration

### 1. Use the Validation Script
```bash
# Test execution name generation
./scripts/validate-step-function-input.sh generate-sample-name "smoketest" "owner/repo" "a1b2c3d4e5f6" "john.doe" "123"

# Validate your JSON input
./scripts/validate-step-function-input.sh validate-json '{"test": "value"}' "Test input"

# Run all tests
./scripts/validate-step-function-input.sh test-all
```

### 2. Test in Development Environment
1. Create a test workflow that uses the executor
2. Trigger it manually with test data
3. Verify the execution name and input in AWS Console

### 3. Monitor Execution Names
Check that your execution names are:
- Descriptive and readable
- Within the 256-character limit
- Include relevant GitHub context

## Common Migration Patterns

### Pattern 1: Simple Replacement
If you have a basic Step Function call, simply replace it with the executor workflow.

### Pattern 2: Complex Input Preparation
If you prepare input data in a separate step, keep that step and pass the output to the executor.

### Pattern 3: Conditional Execution
Add the `if` condition to the executor step instead of the entire job.

### Pattern 4: Multiple Step Functions
Use the executor for each Step Function call, and use job outputs to pass execution ARNs between jobs.

## Troubleshooting Migration

### Issue: Execution Name Too Long
**Solution**: The workflow automatically truncates names, but ensure your prefix is reasonable.

### Issue: Invalid JSON Input
**Solution**: Use the validation script to test your JSON before deployment.

### Issue: Missing GitHub Context
**Solution**: Ensure `include_github_context` is set to `"true"`.

### Issue: Step Function Not Found
**Solution**: Verify the `state_machine_arn` is correct and the workflow has proper AWS permissions.

## Best Practices for Migration

1. **Start Small**: Migrate one workflow at a time
2. **Test Thoroughly**: Use the validation script and test in development
3. **Update Documentation**: Update any documentation that references execution names
4. **Monitor Results**: Check that execution names are helpful in the AWS Console
5. **Train Team**: Ensure your team understands the new execution naming convention

## Rollback Plan

If you need to rollback, you can:

1. Revert to the direct AWS CLI calls
2. Keep the same input data structure
3. Remove the GitHub context from your Step Function logic

The executor is designed to be non-breaking, so your Step Functions will continue to work even if they don't use the GitHub context. 