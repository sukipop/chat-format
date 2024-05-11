#!/usr/bin/env bash
script_name="${0##*/}"
format="llama3"
line_break=0
file_input=""
text_input=""

# Function to display help message
print_usage() {
    echo
    echo "Usage: ${script_name} [options] <input>"
    echo
    echo "Format data for LLM prompting."
    echo
    echo "Options:"
    echo "  -h, --help            Display this help message."
    echo "  -f, --format <format> Prompt format to use."
    echo "  -n                    Use line breaks."
}

# Function to print error message
error() {
    local msg="${1:-Unknown error}"
    echo -e "\033[1;31m\033[1mError\033[0m: $msg" 1>&2
}

# Function to check for required packages
package_check() {
    local required_packages=("jq")
    local missing_packages=()

    # Check for missing packages
    for pkg in "${required_packages[@]}"; do
        if ! command -v "$pkg" &> /dev/null; then
            missing_packages+=("$pkg")
        fi
    done

    # Display error if missing packages
    if [[ "${#missing_packages[@]}" -gt 0 ]]; then
        error "Missing packages: ${missing_packages[*]}"
        return 1
    fi
}

# Function to ensure file is valid
validate_file() {
    # Ensure file is readable
    if [[ ! -r "$1" ]]; then
        error "Failed to read file '$1': Permission denied"
        return 1
    fi

    # Ensure file is not empty
    if [[ ! -s "$1" ]]; then
        error "Empty file: $1"
        return 1
    fi

    # Ensure file is a valid JSON
    if ! cat "$1" | jq >/dev/null; then
        error "Invalid JSON: $1"
        return 1
    fi
}

format_llama3() {
    local role content

    # Define tokens
    local bos_token="<|begin_of_text|>"
    local eot_token="<|eot_id|>"
    local start_header="<|start_header_id|>"
    local stop_header="<|end_header_id|>"

    # Add BOS token
    echo -n "$bos_token"

    # Processes messages from the JSON file
    if [[ -n "$file_input" ]]; then
        while IFS= read -r line; do
            role=$(jq -r '.role' <<< "$line")
            content=$(jq -r '.content' <<< "$line")
            echo -n "${start_header}${role}${stop_header}\n\n"
            echo -n "${content}${eot_token}"
        done < "$file_input"
    fi

    # Add user input if given
    if [[ -n "$text_input" ]]; then
        echo -n "${start_header}user${stop_header}\n\n"
        echo -n "${text_input}${eot_token}"
    fi

    # Add response tokens
    echo -n "${start_header}assistant${stop_header}\n\n"
}

format_chatml() {
    error "Unfinished"
    return 1
}

parse_arguments() {
    while (( "$#" )); do case "$1" in
        # Get some help
        -h|--help|-help|help|h)
            print_usage
            exit 0
            ;;

        # Select format type
        -f|--format)
            if [[ -z "$2" || "$2" =~ -* ]]; then
                error "Missing value for $1"
                return 1
            fi
            format="$2"
            shift
            ;;

        # Handel unknown options
        -*)
            error "Unknown option: $1"
            return 1
            ;;

        # Define 'input'
        *)
            if [[ -f "$1" && -z "$file_input" ]]; then
                file_input="$1"
                validate_file "$file_input"
            elif [[ -z "$text_input" ]]; then
                text_input="$1"
            else
                error
                print_usage
                return 1
            fi
            ;;
        esac
        shift
    done
}

main() {
    # Ensure required packages are available
    package_check || return 1

    # Parse arguments
    if [[ "$#" -gt 0 ]]; then
        parse_arguments "$@"
    else
        error "Missing input"
        print_usage
        return 1
    fi

    # Define 'prompt'
    if [[ "$format" == 'llama3' ]]; then
        prompt=$(format_llama3)
    elif [[ "$format" == 'chatml' ]]; then
        prompt=$(format_chatml)
    else
        error "Unsupported format: $format"
        return 1
    fi

    # Ensure 'prompt' is defined
    if [[ "$?" -gt 0 ]]; then
        error
        return 1
    elif [[ -z "$prompt" ]]; then
        error "Undefined variable: prompt"
        return 1
    else
        echo "$prompt"
        return 0
    fi
}

# Execute script
main "$@"
exit "$?"
