#!/bin/bash

# Step Function Input Validator
# This script helps validate Step Function input data and execution names

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to validate JSON
validate_json() {
    local json_string=$1
    local description=$2
    
    print_status $BLUE "Validating JSON for: $description"
    
    if echo "$json_string" | jq . >/dev/null 2>&1; then
        print_status $GREEN "✓ JSON is valid"
        return 0
    else
        print_status $RED "✗ JSON is invalid"
        echo "$json_string" | jq . 2>&1 || true
        return 1
    fi
}

# Function to validate execution name
validate_execution_name() {
    local execution_name=$1
    local max_length=${2:-256}
    
    print_status $BLUE "Validating execution name: $execution_name"
    
    local length=${#execution_name}
    print_status $BLUE "Length: $length characters (max: $max_length)"
    
    if [ $length -le $max_length ]; then
        print_status $GREEN "✓ Execution name length is within limits"
    else
        print_status $RED "✗ Execution name is too long"
        return 1
    fi
    
    # Check for invalid characters
    if [[ "$execution_name" =~ [^a-zA-Z0-9\-_] ]]; then
        print_status $YELLOW "⚠ Execution name contains potentially problematic characters"
        echo "   AWS Step Functions recommend using only alphanumeric characters, hyphens, and underscores"
    else
        print_status $GREEN "✓ Execution name uses valid characters"
    fi
}

# Function to generate sample execution name
generate_sample_execution_name() {
    local prefix=$1
    local repo=$2
    local sha=$3
    local actor=$4
    local pr_number=${5:-""}
    
    print_status $BLUE "Generating sample execution name..."
    
    local short_sha=$(echo "$sha" | cut -c1-7)
    local repo_name=$(echo "$repo" | sed 's/.*\///')
    
    if [ -n "$pr_number" ]; then
        local exec_name="$prefix-$repo_name-$short_sha-pr$pr_number-$actor"
    else
        local exec_name="$prefix-$repo_name-$short_sha-$actor"
    fi
    
    # Add UUID (first 8 characters only)
    local uuid=$(cat /proc/sys/kernel/random/uuid 2>/dev/null || echo "550e8400e29b41d4a716446655440000")
    local uuid_short=$(echo "$uuid" | tr -d '-' | cut -c1-8)
    exec_name="$exec_name-$uuid_short"
    
    echo "$exec_name"
}

# Function to generate sample GitHub context
generate_sample_github_context() {
    print_status $BLUE "Generating sample GitHub context..."
    
    cat <<EOF
{
  "repository": "owner/repo",
  "ref": "refs/heads/main",
  "sha": "a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0",
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
EOF
}

# Function to show usage
show_usage() {
    cat <<EOF
Step Function Input Validator

Usage: $0 [OPTIONS] COMMAND

Commands:
  validate-json <json_string> <description>  Validate JSON string
  validate-execution-name <name> [max_length] Validate execution name
  generate-sample-name <prefix> <repo> <sha> <actor> [pr_number]  Generate sample execution name
  generate-sample-context  Generate sample GitHub context
  test-all  Run all validation tests

Options:
  -h, --help  Show this help message

Examples:
  $0 validate-json '{"test": "value"}' "Test input"
  $0 validate-execution-name "myapp-repo-a1b2c3d-john.doe-550e8400e29b41d4a716446655440000"
  $0 generate-sample-name "smoketest" "owner/repo" "a1b2c3d4e5f6" "john.doe" "123"
  $0 test-all
EOF
}

# Function to run all tests
run_all_tests() {
    print_status $BLUE "Running all validation tests..."
    echo
    
    # Test 1: Valid JSON
    print_status $YELLOW "Test 1: Valid JSON"
    validate_json '{"environment": "prod", "data": "test"}' "Valid JSON"
    echo
    
    # Test 2: Invalid JSON
    print_status $YELLOW "Test 2: Invalid JSON"
    validate_json '{"environment": "prod", "data": "test"' "Invalid JSON"
    echo
    
    # Test 3: Valid execution name
    print_status $YELLOW "Test 3: Valid execution name"
    validate_execution_name "smoketest-myapp-a1b2c3d-john.doe-550e8400e29b41d4a716446655440000"
    echo
    
    # Test 4: Long execution name
    print_status $YELLOW "Test 4: Long execution name"
    long_name="very-long-prefix-very-long-repository-name-very-long-commit-sha-very-long-actor-name-very-long-uuid-very-long-suffix-very-long-extension-very-long-addition-very-long-appendage-very-long-extension-very-long-suffix"
    validate_execution_name "$long_name"
    echo
    
    # Test 5: Generate sample execution name
    print_status $YELLOW "Test 5: Generate sample execution name"
    sample_name=$(generate_sample_execution_name "smoketest" "owner/repo" "a1b2c3d4e5f6" "john.doe" "123")
    echo "Generated: $sample_name"
    validate_execution_name "$sample_name"
    echo
    
    # Test 6: Generate sample context
    print_status $YELLOW "Test 6: Generate sample GitHub context"
    sample_context=$(generate_sample_github_context)
    echo "$sample_context" | jq .
    echo
    
    print_status $GREEN "All tests completed!"
}

# Main script logic
case "${1:-}" in
    "validate-json")
        if [ $# -lt 3 ]; then
            print_status $RED "Error: Missing arguments for validate-json"
            show_usage
            exit 1
        fi
        validate_json "$2" "$3"
        ;;
    "validate-execution-name")
        if [ $# -lt 2 ]; then
            print_status $RED "Error: Missing execution name"
            show_usage
            exit 1
        fi
        validate_execution_name "$2" "${3:-256}"
        ;;
    "generate-sample-name")
        if [ $# -lt 5 ]; then
            print_status $RED "Error: Missing arguments for generate-sample-name"
            show_usage
            exit 1
        fi
        generate_sample_execution_name "$2" "$3" "$4" "$5" "${6:-}"
        ;;
    "generate-sample-context")
        generate_sample_github_context
        ;;
    "test-all")
        run_all_tests
        ;;
    "-h"|"--help"|"")
        show_usage
        ;;
    *)
        print_status $RED "Error: Unknown command '$1'"
        show_usage
        exit 1
        ;;
esac 