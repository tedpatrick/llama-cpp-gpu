#!/bin/bash
set -e

# Logging functions
log_info() {
    echo "[INFO] $1"
}

log_error() {
    echo "[ERROR] $1" >&2
}

log_warning() {
    echo "[WARNING] $1" >&2
}

# Set default CACHE_ROOT if not provided
CACHE_ROOT="${CACHE_ROOT:-/mnt/vol}"

# Required environment variables - exit if not set
if [ -z "$MODEL_UUID" ]; then
    log_error "MODEL_UUID environment variable is required but not set"
    exit 1
fi

if [ -z "$FILE_UUID" ]; then
    log_error "FILE_UUID environment variable is required but not set"
    exit 1
fi

if [ -z "$DOWNLOAD_URL" ]; then
    log_error "DOWNLOAD_URL environment variable is required but not set"
    exit 1
fi

# Extract filename from download URL
extract_filename_from_url() {
    local url="$1"
    # Remove query parameters and extract last path segment
    local path="${url%%\?*}"
    local filename="${path##*/}"
    
    if [ -z "$filename" ]; then
        log_error "Could not extract filename from URL: $url"
        exit 1
    fi
    
    # URL decode the filename (basic implementation)
    printf '%b' "${filename//%/\\x}"
}

# Download model file
download_model_file() {
    local download_url="$1"
    local cached_model="$2"
    
    if [ -f "$cached_model" ]; then
        log_info "Model already cached at $cached_model"
        return 0
    fi
    
    log_info "Downloading model from $download_url to $cached_model"
    
    # Ensure the parent directory exists
    mkdir -p "$(dirname "$cached_model")"
    
    # Download the file using wget or curl
    if command -v wget &> /dev/null; then
        if ! wget -O "$cached_model" "$download_url"; then
            log_error "Failed to download model"
            # Clean up partial download
            if [ -f "$cached_model" ]; then
                rm -f "$cached_model"
                log_info "Cleaned up partial download: $cached_model"
            fi
            exit 1
        fi
    elif command -v curl &> /dev/null; then
        if ! curl -L -o "$cached_model" "$download_url"; then
            log_error "Failed to download model"
            # Clean up partial download
            if [ -f "$cached_model" ]; then
                rm -f "$cached_model"
                log_info "Cleaned up partial download: $cached_model"
            fi
            exit 1
        fi
    else
        log_error "Neither wget nor curl is available for downloading"
        exit 1
    fi
    
    log_info "Successfully downloaded model to $cached_model"
}

# Start llama.cpp server
start_server() {
    local model_path="$1"
    
    # Check if llama-server is available
    if ! command -v llama-server &> /dev/null; then
        log_error "llama-server binary not found"
        exit 1
    fi
    
    log_info "Starting llama.cpp server"
    log_info "Command: llama-server -m $model_path --host 0.0.0.0 --metrics"
    
    # Start the server (exec replaces the shell process)
    exec llama-server \
        -m "$model_path" \
        --host 0.0.0.0 \
        --metrics
}

# Main execution
main() {
    # Extract filename from download URL
    filename=$(extract_filename_from_url "$DOWNLOAD_URL")
    
    # Build cache paths
    cache_path="${CACHE_ROOT}/models/${MODEL_UUID}/quantized/${FILE_UUID}"
    cached_model="${cache_path}/${filename}"
    
    # Download model if needed
    download_model_file "$DOWNLOAD_URL" "$cached_model"
    
    # Start the server
    log_info "Running for model $MODEL_UUID and quant $FILE_UUID"
    start_server "$cached_model"
}

# Run main function
main
