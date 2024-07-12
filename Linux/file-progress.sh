#!/bin/bash

# Define colors
RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
YELLOW=$(tput setaf 3)
BLUE=$(tput setaf 4)
MAGENTA=$(tput setaf 5)
CYAN=$(tput setaf 6)
WHITE=$(tput setaf 7)
RESET=$(tput sgr0)

total_size_gb=60
total_size_bytes=$((total_size_gb * 1024 * 1024 * 1024))
start_time=$(date +%s)
file_path="/mnt/immiche-steve/admin-all.tgz"
graph_width=5  # Width of the graph
max_speed_seen=0
no_change_threshold=60  # Time threshold in seconds for no change

convert_seconds() {
    local seconds=$1
    local hours=$((seconds / 3600))
    local minutes=$(( (seconds % 3600) / 60))
    local remaining_seconds=$((seconds % 60))
    printf "%02d:%02d:%02d" $hours $minutes $remaining_seconds
}

generate_progress_bar() {
    local progress=$1
    local width=50
    local filled=$(awk -v p="$progress" -v w="$width" 'BEGIN {printf "%.0f", p * w / 100}')
    local empty=$((width - filled))
    printf "["
    printf "${GREEN}#%.0s${RESET}" $(seq 1 $filled)
    printf " %.0s" $(seq 1 $empty)
    printf "]"
}

draw_vertical_graph() {
    local data=("$@")
    local term_height=$(tput lines)
    local output_lines=17  # Adjust this based on the number of lines in the output above the graph
    local graph_height=$((term_height - output_lines))  # Adjust based on terminal height
    local max_value=$(printf "%s\n" "${data[@]}" | sort -nr | head -n1)
    local scale=$(awk -v max="$max_value" -v height="$graph_height" 'BEGIN {printf "%.2f", height / max}')
    
    local graph=()
    for value in "${data[@]}"; do
        local length=$(awk -v val="$value" -v scale="$scale" 'BEGIN {printf "%.0f", val * scale}')
        graph+=("$length")
    done
    
    for ((i = graph_height; i >= 0; i--)); do
        for bar in "${graph[@]}"; do
            if [ "$bar" -ge "$i" ]; then
                printf " ${BLUE}%-5s${RESET}" "#"
            else
                printf " %-5s" " "
            fi
        done
        printf "\n"
    done
    
    for value in "${data[@]}"; do
        printf " ${CYAN}%-5.1f${RESET}" "$value"
    done
    printf "\n"
}

clear_screen() {
    tput clear  # Clear the entire screen
}

previous_size_bytes=0
previous_time=$start_time
last_change_time=$start_time
total_speed=0
update_count=0
speed_data=()

# Clear the screen on start and when the terminal is resized
clear_screen
trap clear_screen SIGWINCH

while true; do
    tput civis  # Hide cursor
    tput cup 0 0  # Move cursor to the top left

    echo "${YELLOW}Checking file: $file_path${RESET}"
    echo "------------------------------------"
    
    if [ -f "$file_path" ]; then
        current_time=$(date +%s)
        processed_size_bytes=$(du -b "$file_path" | cut -f1)
        processed_size_gb=$(awk 'BEGIN {printf "%.2f", '"$processed_size_bytes"' / (1024*1024*1024)}')
        
        if [ "$processed_size_bytes" -ne "$previous_size_bytes" ]; then
            last_change_time=$current_time
        fi

        no_change_time=$((current_time - last_change_time))
        if [ "$no_change_time" -ge "$no_change_threshold" ]; then
            echo "${RED}No change in file size for $no_change_threshold seconds. Exiting.${RESET}"
            tput cnorm  # Show cursor
            exit 0
        fi
        
        progress=$(awk 'BEGIN {printf "%.2f", ('"$processed_size_gb"' / '"$total_size_gb"') * 100}')
        elapsed_time=$((current_time - start_time))
        total_elapsed_time_formatted=$(convert_seconds $elapsed_time)
        
        bytes_diff=$((processed_size_bytes - previous_size_bytes))
        time_diff=$((current_time - previous_time))
        if [ $time_diff -gt 0 ]; then
            speed=$(awk 'BEGIN {printf "%.2f", '"$bytes_diff"' / (1024*1024) / '"$time_diff"'}')
        else
            speed="N/A"
        fi
        
        if [[ $speed != "N/A" ]]; then
            total_speed=$(awk 'BEGIN {print '"$total_speed"' + '"$speed"'}')
            update_count=$((update_count + 1))
            avg_speed=$(awk 'BEGIN {printf "%.2f", '"$total_speed"' / '"$update_count"'}')
            speed_data+=("$speed")
            max_speed_seen=$(awk -v speed="$speed" -v max_speed_seen="$max_speed_seen" 'BEGIN {if (speed > max_speed_seen) {print speed} else {print max_speed_seen}}')
        else
            avg_speed="N/A"
        fi
        
        if [ ${#speed_data[@]} -gt $graph_width ]; then
            speed_data=("${speed_data[@]:1}")
        fi
        
        if [[ $speed != "N/A" && $(awk 'BEGIN {print ('"$speed"' > 0)}') -eq 1 ]]; then
            remaining_bytes=$((total_size_bytes - processed_size_bytes))
            remaining_time_current=$(awk 'BEGIN {printf "%.0f", '"$remaining_bytes"' / ('"$speed"' * 1024 * 1024)}')
            remaining_time_current_formatted=$(convert_seconds $remaining_time_current)
        else
            remaining_time_current_formatted="N/A"
        fi
        
        if [[ $avg_speed != "N/A" && $(awk 'BEGIN {print ('"$avg_speed"' > 0)}') -eq 1 ]]; then
            remaining_time_avg=$(awk 'BEGIN {printf "%.0f", '"$remaining_bytes"' / ('"$avg_speed"' * 1024 * 1024)}')
            remaining_time_avg_formatted=$(convert_seconds $remaining_time_avg)
        else
            remaining_time_avg_formatted="N/A"
        fi
        
        echo "${MAGENTA}Processed size: $processed_size_gb GB / $total_size_gb GB${RESET}"
        echo "${MAGENTA}Progress: $progress%${RESET}"
        generate_progress_bar $progress
        echo
        echo "${GREEN}Current speed: $speed MB/s${RESET}"
        echo "${GREEN}Average speed: $avg_speed MB/s${RESET}"
        echo "${GREEN}Maximum speed seen: $max_speed_seen MB/s${RESET}"
        echo "${CYAN}Total elapsed time: $total_elapsed_time_formatted${RESET}"
        echo "${CYAN}Estimated time remaining (current speed): $remaining_time_current_formatted${RESET}"
        echo "${CYAN}Estimated time remaining (average speed): $remaining_time_avg_formatted${RESET}"
        echo "------------------------------------"
        draw_vertical_graph "${speed_data[@]}"
        
        previous_size_bytes=$processed_size_bytes
        previous_time=$current_time
    else
        echo "${RED}File not found: $file_path${RESET}"
    fi
    
    echo "------------------------------------"

    tput cnorm  # Show cursor
    sleep 1
done
