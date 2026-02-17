#!/usr/bin/env bash

################################################################################
# Network Ping Sweep Monitor
#
# Purpose: Performs parallel ping sweep to identify active hosts on a network
# Author: Systems Administration Team
# Version: 1.0.0
#
# Dependencies:
#   - bash 4.0+
#   - ping (iputils-ping)
#   - ipcalc or manual CIDR calculation
#   - GNU parallel (optional, will use xargs fallback)
#
# Usage:
#   ./ping_sweep.sh <network_range> [options]
#   ./ping_sweep.sh 192.168.1.0/24
#   ./ping_sweep.sh 10.0.0.0/24 --continuous --interval 300
#   ./ping_sweep.sh 172.16.0.0/16 --timeout 2 --parallel 50
#
# Options:
#   -c, --continuous       Run continuously with specified interval
#   -i, --interval SEC     Interval between sweeps (default: 300)
#   -t, --timeout SEC      Ping timeout per host (default: 1)
#   -p, --parallel NUM     Number of parallel pings (default: 50)
#   -o, --output FILE      Save results to file
#   -q, --quiet            Minimal output (only active hosts)
#   -n, --no-color         Disable colored output
#   --dry-run              Show what would be scanned without pinging
#   -h, --help             Show this help message
#
################################################################################

set -uo pipefail

# Script metadata
readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly VERSION="1.0.0"

# Default configuration
DEFAULT_TIMEOUT=1
DEFAULT_PARALLEL=50
DEFAULT_INTERVAL=300
CONTINUOUS=false
INTERVAL=$DEFAULT_INTERVAL
TIMEOUT=$DEFAULT_TIMEOUT
PARALLEL=$DEFAULT_PARALLEL
OUTPUT_FILE=""
QUIET=false
NO_COLOR=false
DRY_RUN=false

# Color codes (will be disabled if NO_COLOR is set)
COLOR_RED='\033[0;31m'
COLOR_GREEN='\033[0;32m'
COLOR_YELLOW='\033[1;33m'
COLOR_BLUE='\033[0;34m'
COLOR_CYAN='\033[0;36m'
COLOR_BOLD='\033[1m'
COLOR_RESET='\033[0m'

# Statistics counters
TOTAL_HOSTS=0
ACTIVE_HOSTS=0
INACTIVE_HOSTS=0
SCAN_START_TIME=0
SCAN_END_TIME=0

################################################################################
# Utility Functions
################################################################################

# Print error message and exit
error_exit() {
    echo -e "${COLOR_RED}ERROR: $1${COLOR_RESET}" >&2
    exit "${2:-1}"
}

# Print warning message
warn() {
    echo -e "${COLOR_YELLOW}WARNING: $1${COLOR_RESET}" >&2
}

# Print info message
info() {
    if [[ "$QUIET" != true ]]; then
        echo -e "${COLOR_CYAN}INFO: $1${COLOR_RESET}"
    fi
}

# Print success message
success() {
    echo -e "${COLOR_GREEN}$1${COLOR_RESET}"
}

# Setup color codes based on terminal capabilities and user preference
setup_colors() {
    if [[ "$NO_COLOR" == true ]] || [[ ! -t 1 ]]; then
        COLOR_RED=""
        COLOR_GREEN=""
        COLOR_YELLOW=""
        COLOR_BLUE=""
        COLOR_CYAN=""
        COLOR_BOLD=""
        COLOR_RESET=""
    fi
}

# Display usage information
usage() {
    cat << EOF
${COLOR_BOLD}Network Ping Sweep Monitor v${VERSION}${COLOR_RESET}

${COLOR_BOLD}USAGE:${COLOR_RESET}
    $SCRIPT_NAME <network_range> [options]

${COLOR_BOLD}ARGUMENTS:${COLOR_RESET}
    network_range          Network in CIDR notation (e.g., 192.168.1.0/24)

${COLOR_BOLD}OPTIONS:${COLOR_RESET}
    -c, --continuous       Run continuously with specified interval
    -i, --interval SEC     Interval between sweeps in seconds (default: 300)
    -t, --timeout SEC      Ping timeout per host in seconds (default: 1)
    -p, --parallel NUM     Number of parallel pings (default: 50)
    -o, --output FILE      Save results to file (appends timestamp)
    -q, --quiet            Minimal output (only active hosts)
    -n, --no-color         Disable colored output
    --dry-run              Show what would be scanned without pinging
    -h, --help             Show this help message

${COLOR_BOLD}EXAMPLES:${COLOR_RESET}
    # Basic sweep of /24 network
    $SCRIPT_NAME 192.168.1.0/24

    # Continuous monitoring every 5 minutes
    $SCRIPT_NAME 192.168.1.0/24 --continuous --interval 300

    # Fast sweep with higher parallelism and shorter timeout
    $SCRIPT_NAME 10.0.0.0/24 --timeout 0.5 --parallel 100

    # Quiet mode with output logging
    $SCRIPT_NAME 172.16.0.0/24 --quiet --output /var/log/ping_sweep.log

    # Dry run to see what would be scanned
    $SCRIPT_NAME 192.168.0.0/16 --dry-run

EOF
}

# Validate IP address format
validate_ip() {
    local ip=$1
    local stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        IFS='.' read -ra ADDR <<< "$ip"
        [[ ${ADDR[0]} -le 255 && ${ADDR[1]} -le 255 && \
           ${ADDR[2]} -le 255 && ${ADDR[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

# Validate CIDR notation
validate_cidr() {
    local cidr=$1
    local ip prefix

    if [[ ! $cidr =~ ^([0-9.]+)/([0-9]+)$ ]]; then
        return 1
    fi

    ip="${BASH_REMATCH[1]}"
    prefix="${BASH_REMATCH[2]}"

    validate_ip "$ip" || return 1
    [[ $prefix -ge 0 && $prefix -le 32 ]] || return 1

    return 0
}

# Convert IP to integer
ip_to_int() {
    local ip=$1
    local a b c d
    IFS='.' read -r a b c d <<< "$ip"
    echo "$((a * 256 ** 3 + b * 256 ** 2 + c * 256 + d))"
}

# Convert integer to IP
int_to_ip() {
    local int=$1
    echo "$((int >> 24 & 255)).$((int >> 16 & 255)).$((int >> 8 & 255)).$((int & 255))"
}

# Calculate network range from CIDR
calculate_network_range() {
    local cidr=$1
    local ip prefix

    IFS='/' read -r ip prefix <<< "$cidr"

    local ip_int
    ip_int=$(ip_to_int "$ip")

    # Calculate netmask
    local netmask_int=$((0xFFFFFFFF << (32 - prefix) & 0xFFFFFFFF))

    # Calculate network address
    local network_int=$((ip_int & netmask_int))

    # Calculate broadcast address
    local broadcast_int=$((network_int | (0xFFFFFFFF >> prefix)))

    # Calculate first and last usable host
    local first_host=$((network_int + 1))
    local last_host=$((broadcast_int - 1))

    # For /31 and /32 networks, adjust accordingly
    if [[ $prefix -eq 31 ]]; then
        first_host=$network_int
        last_host=$broadcast_int
    elif [[ $prefix -eq 32 ]]; then
        first_host=$network_int
        last_host=$network_int
    fi

    echo "$first_host $last_host"
}

# Check if required commands are available
check_dependencies() {
    local missing_deps=()

    if ! command -v ping &> /dev/null; then
        missing_deps+=("ping (install iputils-ping)")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        error_exit "Missing required dependencies: ${missing_deps[*]}"
    fi

    # Check for GNU parallel (optional)
    if command -v parallel &> /dev/null; then
        info "Using GNU parallel for improved performance"
    else
        info "GNU parallel not found, using xargs fallback (consider installing for better performance)"
    fi
}

# Perform single ping check
ping_host() {
    local ip=$1
    local timeout=$2

    # Use appropriate ping command based on OS
    if ping -c 1 -W "$timeout" "$ip" &> /dev/null; then
        echo "ACTIVE:$ip"
        return 0
    else
        echo "INACTIVE:$ip"
        return 1
    fi
}

# Export function for parallel execution
export -f ping_host

# Generate list of IP addresses to scan
generate_ip_list() {
    local first_host=$1
    local last_host=$2

    for ((ip_int=first_host; ip_int<=last_host; ip_int++)); do
        int_to_ip "$ip_int"
    done
}

# Perform parallel ping sweep
perform_ping_sweep() {
    local network_range=$1
    local timestamp
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    info "Starting ping sweep of $network_range at $timestamp"

    # Calculate IP range
    local range_result
    range_result=$(calculate_network_range "$network_range")
    read -r first_host last_host <<< "$range_result"

    TOTAL_HOSTS=$((last_host - first_host + 1))

    if [[ "$DRY_RUN" == true ]]; then
        echo -e "${COLOR_YELLOW}DRY RUN MODE${COLOR_RESET}"
        echo "Would scan $TOTAL_HOSTS hosts:"
        echo "  First host: $(int_to_ip "$first_host")"
        echo "  Last host:  $(int_to_ip "$last_host")"
        return 0
    fi

    if [[ "$QUIET" != true ]]; then
        echo -e "${COLOR_BOLD}Scanning $TOTAL_HOSTS hosts in range: $(int_to_ip "$first_host") - $(int_to_ip "$last_host")${COLOR_RESET}"
        echo ""
    fi

    SCAN_START_TIME=$(date +%s)
    ACTIVE_HOSTS=0
    INACTIVE_HOSTS=0

    # Create temporary file for results
    local temp_results=""
    temp_results=$(mktemp)
    # shellcheck disable=SC2064
    trap "rm -f '$temp_results'" RETURN

    # Generate IP list and perform parallel ping
    if command -v parallel &> /dev/null; then
        # Use GNU parallel for better performance
        if [[ -t 1 ]]; then
            # Use progress bar only when running in a terminal
            generate_ip_list "$first_host" "$last_host" | \
                parallel -j "$PARALLEL" --bar --eta ping_host {} "$TIMEOUT" > "$temp_results" 2>/dev/null
        else
            # No progress bar for non-TTY environments
            generate_ip_list "$first_host" "$last_host" | \
                parallel -j "$PARALLEL" ping_host {} "$TIMEOUT" > "$temp_results" 2>&1
        fi
    else
        # Fallback to xargs
        generate_ip_list "$first_host" "$last_host" | \
            xargs -I {} -P "$PARALLEL" bash -c \
                'if ping -c 1 -W '"$TIMEOUT"' "$1" &>/dev/null; then echo "ACTIVE:$1"; else echo "INACTIVE:$1"; fi' \
                _ {} > "$temp_results"
    fi

    SCAN_END_TIME=$(date +%s)

    # Process results
    local active_ips=()
    local inactive_ips=()

    while IFS=: read -r status ip; do
        if [[ "$status" == "ACTIVE" ]]; then
            active_ips+=("$ip")
            ((ACTIVE_HOSTS++))
        else
            inactive_ips+=("$ip")
            ((INACTIVE_HOSTS++))
        fi
    done < "$temp_results"

    # Display results
    display_results "$network_range" "$timestamp" "${active_ips[@]+"${active_ips[@]}"}" "---SEPARATOR---" "${inactive_ips[@]+"${inactive_ips[@]}"}"

    # Save to file if specified
    if [[ -n "$OUTPUT_FILE" ]]; then
        save_results "$network_range" "$timestamp" "${active_ips[@]+"${active_ips[@]}"}"
    fi
}

# Display scan results
display_results() {
    local network_range=$1
    local timestamp=$2
    shift 2

    # Separate active and inactive IPs
    local active_ips=()
    local inactive_ips=()
    local processing_active=true

    for arg in "$@"; do
        if [[ "$arg" == "---SEPARATOR---" ]]; then
            processing_active=false
            continue
        fi
        if [[ "$processing_active" == true ]]; then
            active_ips+=("$arg")
        else
            inactive_ips+=("$arg")
        fi
    done

    echo ""
    echo -e "${COLOR_BOLD}=== PING SWEEP RESULTS ===${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Network:${COLOR_RESET} $network_range"
    echo -e "${COLOR_BOLD}Timestamp:${COLOR_RESET} $timestamp"
    echo -e "${COLOR_BOLD}Scan Duration:${COLOR_RESET} $((SCAN_END_TIME - SCAN_START_TIME)) seconds"
    echo ""

    # Active hosts
    if [[ ${#active_ips[@]} -gt 0 ]]; then
        echo -e "${COLOR_GREEN}${COLOR_BOLD}ACTIVE HOSTS ($ACTIVE_HOSTS):${COLOR_RESET}"
        for ip in "${active_ips[@]}"; do
            success "  [UP]   $ip"
        done
        echo ""
    else
        echo -e "${COLOR_YELLOW}No active hosts found${COLOR_RESET}"
        echo ""
    fi

    # Inactive hosts: show count only
    if [[ ${#inactive_ips[@]} -gt 0 ]]; then
        echo -e "${COLOR_RED}${COLOR_BOLD}INACTIVE HOSTS: $INACTIVE_HOSTS${COLOR_RESET}"
        echo ""
    fi

    # Summary statistics
    echo -e "${COLOR_BOLD}=== SUMMARY STATISTICS ===${COLOR_RESET}"
    echo -e "${COLOR_BOLD}Total Hosts:${COLOR_RESET}    $TOTAL_HOSTS"
    echo -e "${COLOR_GREEN}${COLOR_BOLD}Active Hosts:${COLOR_RESET}   $ACTIVE_HOSTS${COLOR_RESET}"
    echo -e "${COLOR_RED}${COLOR_BOLD}Inactive Hosts:${COLOR_RESET} $INACTIVE_HOSTS${COLOR_RESET}"

    local availability_pct=0
    if [[ $TOTAL_HOSTS -gt 0 ]]; then
        availability_pct=$((ACTIVE_HOSTS * 100 / TOTAL_HOSTS))
    fi
    echo -e "${COLOR_BOLD}Availability:${COLOR_RESET}   ${availability_pct}%"
    echo ""
}

# Save results to output file
save_results() {
    local network_range=$1
    local timestamp=$2
    shift 2
    local active_ips=("$@")

    {
        echo "=== PING SWEEP RESULTS ==="
        echo "Network: $network_range"
        echo "Timestamp: $timestamp"
        echo "Scan Duration: $((SCAN_END_TIME - SCAN_START_TIME)) seconds"
        echo ""
        echo "ACTIVE HOSTS ($ACTIVE_HOSTS):"
        for ip in "${active_ips[@]}"; do
            echo "  [UP] $ip"
        done
        echo ""
        echo "=== SUMMARY STATISTICS ==="
        echo "Total Hosts:    $TOTAL_HOSTS"
        echo "Active Hosts:   $ACTIVE_HOSTS"
        echo "Inactive Hosts: $INACTIVE_HOSTS"
        echo "Availability:   $((ACTIVE_HOSTS * 100 / TOTAL_HOSTS))%"
        echo ""
        echo "---"
        echo ""
    } >> "$OUTPUT_FILE"

    info "Results saved to $OUTPUT_FILE"
}

# Continuous monitoring loop
continuous_monitoring() {
    local network_range=$1

    info "Starting continuous monitoring mode (interval: ${INTERVAL}s)"
    info "Press Ctrl+C to stop"
    echo ""

    # Setup signal handler for graceful shutdown
    trap 'echo ""; info "Monitoring stopped"; exit 0' INT TERM

    local iteration=1
    while true; do
        echo -e "${COLOR_BOLD}${COLOR_BLUE}=== Scan Iteration #$iteration ===${COLOR_RESET}"
        perform_ping_sweep "$network_range"

        if [[ "$CONTINUOUS" == true ]]; then
            info "Next scan in ${INTERVAL} seconds..."
            echo ""
            sleep "$INTERVAL"
            ((iteration++))
        else
            break
        fi
    done
}

################################################################################
# Main Function
################################################################################

main() {
    # Setup colors first so all output is correctly formatted
    setup_colors

    # Parse command line arguments
    local network_range=""

    if [[ $# -eq 0 ]]; then
        usage
        exit 0
    fi

    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                usage
                exit 0
                ;;
            -c|--continuous)
                CONTINUOUS=true
                shift
                ;;
            -i|--interval)
                INTERVAL="$2"
                if ! [[ "$INTERVAL" =~ ^[0-9]+$ ]] || [[ $INTERVAL -lt 1 ]]; then
                    error_exit "Interval must be a positive integer"
                fi
                shift 2
                ;;
            -t|--timeout)
                TIMEOUT="$2"
                if ! [[ "$TIMEOUT" =~ ^[0-9.]+$ ]]; then
                    error_exit "Timeout must be a positive number"
                fi
                shift 2
                ;;
            -p|--parallel)
                PARALLEL="$2"
                if ! [[ "$PARALLEL" =~ ^[0-9]+$ ]] || [[ $PARALLEL -lt 1 ]]; then
                    error_exit "Parallel count must be a positive integer"
                fi
                shift 2
                ;;
            -o|--output)
                OUTPUT_FILE="$2"
                # Validate output directory exists
                local output_dir
                output_dir=$(dirname "$OUTPUT_FILE")
                if [[ ! -d "$output_dir" ]]; then
                    error_exit "Output directory does not exist: $output_dir"
                fi
                shift 2
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -n|--no-color)
                NO_COLOR=true
                shift
                ;;
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            -*)
                error_exit "Unknown option: $1"
                ;;
            *)
                if [[ -z "$network_range" ]]; then
                    network_range="$1"
                else
                    error_exit "Multiple network ranges specified. Please provide only one."
                fi
                shift
                ;;
        esac
    done

    # Validate network range is provided
    if [[ -z "$network_range" ]]; then
        error_exit "Network range is required. Use -h for help."
    fi

    # Validate network range format
    if ! validate_cidr "$network_range"; then
        error_exit "Invalid CIDR notation: $network_range"
    fi

    # Check dependencies
    check_dependencies

    # Warn about large network scans
    local prefix
    prefix=$(echo "$network_range" | cut -d'/' -f2)
    local host_count=$((2 ** (32 - prefix)))

    if [[ $host_count -gt 1024 ]] && [[ "$DRY_RUN" != true ]]; then
        warn "Large network detected (~$host_count hosts). This may take several minutes."
        warn "Consider using a smaller range or higher parallelism for faster results."
        echo ""
    fi

    # Start monitoring
    if [[ "$CONTINUOUS" == true ]]; then
        continuous_monitoring "$network_range"
    else
        perform_ping_sweep "$network_range"
    fi
}

# Execute main function
main "$@"
