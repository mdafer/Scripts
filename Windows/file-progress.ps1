# Define colors
$colors = @{
    RED     = [ConsoleColor]::Red
    GREEN   = [ConsoleColor]::Green
    YELLOW  = [ConsoleColor]::Yellow
    BLUE    = [ConsoleColor]::Blue
    MAGENTA = [ConsoleColor]::Magenta
    CYAN    = [ConsoleColor]::Cyan
    WHITE   = [ConsoleColor]::White
    RESET   = [ConsoleColor]::White
}

$total_size_gb = 60
$total_size_bytes = $total_size_gb * 1GB
$start_time = Get-Date
$file_path = "$HOME\Downloads\combined_denise.tgz"
$graph_width = 5  # Width of the graph
$max_speed_seen = 0
$no_change_threshold = 60  # Time threshold in seconds for no change

# Function to convert seconds to HH:MM:SS format
function Convert-Seconds {
    param (
        [int]$seconds
    )
    return [TimeSpan]::FromSeconds($seconds).ToString("hh\:mm\:ss")
}

# Function to generate a progress bar
function Generate-ProgressBar {
    param (
        [float]$progress
    )
    $width = 50
    $filled = [math]::Round($progress * $width / 100)
    $empty = $width - $filled
    Write-Host "[" -NoNewline
    Write-Host ("#" * $filled) -ForegroundColor $colors.GREEN -NoNewline
    Write-Host (" " * $empty) -NoNewline
    Write-Host "]"
}

# Function to draw a vertical graph
function Draw-VerticalGraph {
    param (
        [float[]]$data
    )
    $term_height = [Console]::WindowHeight
    $output_lines = 17  # Adjust this based on the number of lines in the output above the graph
    $graph_height = $term_height - $output_lines  # Adjust based on terminal height
    $max_value = ($data | Measure-Object -Maximum).Maximum
    if ($max_value -eq 0) {
        $max_value = 1  # Prevent division by zero
    }
    $scale = $graph_height / $max_value

    $graph = @()
    foreach ($value in $data) {
        $length = [math]::Round($value * $scale)
        $graph += $length
    }

    for ($i = $graph_height; $i -ge 0; $i--) {
        foreach ($bar in $graph) {
            if ($bar -ge $i) {
                Write-Host "     " -NoNewline
                Write-Host "#" -ForegroundColor $colors.BLUE -NoNewline
            } else {
                Write-Host "      " -NoNewline
            }
        }
        Write-Host ""
    }

    foreach ($value in $data) {
        Write-Host (" " + [string]::Format("{0,5:0.0}", $value)) -ForegroundColor $colors.CYAN -NoNewline
    }
    Write-Host ""
}

function Clear-Screen {
    Clear-Host
}

$previous_size_bytes = 0
$previous_time = $start_time
$last_change_time = $start_time
$total_speed = 0
$update_count = 0
$speed_data = @()
$initial_size_bytes = (Get-Item $file_path).length  # Record initial size
$first_change = $true  # Flag to ignore the initial change

# Clear the screen on start and periodically
Clear-Screen
$clear_screen_interval = 10
$last_clear_time = Get-Date

while ($true) {
    [Console]::CursorVisible = $false
    [Console]::SetCursorPosition(0, 0)

    $current_time = Get-Date
    if (($current_time - $last_clear_time).TotalSeconds -ge $clear_screen_interval) {
        Clear-Screen
        $last_clear_time = $current_time
    }

    Write-Host "Checking file: $file_path" -ForegroundColor $colors.YELLOW
    Write-Host "------------------------------------"
    
    if (Test-Path $file_path) {
        $processed_size_bytes = (Get-Item $file_path).length
        $processed_size_gb = [math]::Round(($processed_size_bytes - $initial_size_bytes) / 1GB, 2)

        if ($processed_size_bytes -ne $previous_size_bytes) {
            $last_change_time = $current_time
        }

        $no_change_time = ($current_time - $last_change_time).TotalSeconds
        if ($no_change_time -ge $no_change_threshold) {
            Write-Host "No change in file size for $no_change_threshold seconds. Exiting." -ForegroundColor $colors.RED
            [Console]::CursorVisible = $true
            exit
        }

        $progress = [math]::Round(($processed_size_bytes - $initial_size_bytes) / $total_size_bytes * 100, 2)
        $elapsed_time = ($current_time - $start_time).TotalSeconds
        $total_elapsed_time_formatted = Convert-Seconds $elapsed_time

        $bytes_diff = $processed_size_bytes - $previous_size_bytes
        $time_diff = ($current_time - $previous_time).TotalSeconds
        if ($time_diff -gt 0) {
            $speed = [math]::Round($bytes_diff / 1MB / $time_diff, 2)
        } else {
            $speed = 0
        }

        if ($speed -gt 0 -and -not $first_change) {
            $total_speed += $speed
            $update_count++
            $avg_speed = [math]::Round($total_speed / $update_count, 2)
            $speed_data += $speed
            if ($speed -gt $max_speed_seen) {
                $max_speed_seen = $speed
            }
        } elseif (-not $first_change) {
            $avg_speed = "N/A"
        } else {
            $first_change = $false
        }

        if ($speed_data.Length -gt $graph_width) {
            $speed_data = $speed_data[-($graph_width)..-1]
        }

        if ($speed -gt 0) {
            $remaining_bytes = $total_size_bytes - ($processed_size_bytes - $initial_size_bytes)
            $remaining_time_current = [math]::Round($remaining_bytes / 1MB / $speed)
            $remaining_time_current_formatted = Convert-Seconds $remaining_time_current
        } else {
            $remaining_time_current_formatted = "N/A"
        }

        if ($avg_speed -ne "N/A" -and $avg_speed -gt 0) {
            $remaining_time_avg = [math]::Round($remaining_bytes / 1MB / $avg_speed)
            $remaining_time_avg_formatted = Convert-Seconds $remaining_time_avg
        } else {
            $remaining_time_avg_formatted = "N/A"
        }

        Write-Host "Processed size: $processed_size_gb GB / $total_size_gb GB" -ForegroundColor $colors.MAGENTA
        Write-Host "Progress: $progress%" -ForegroundColor $colors.MAGENTA
        Generate-ProgressBar $progress
        Write-Host ""
        Write-Host "Current speed: $speed MB/s" -ForegroundColor $colors.GREEN
        Write-Host "Average speed: $avg_speed MB/s" -ForegroundColor $colors.GREEN
        Write-Host "Maximum speed seen: $max_speed_seen MB/s" -ForegroundColor $colors.GREEN
        Write-Host "Total elapsed time: $total_elapsed_time_formatted" -ForegroundColor $colors.CYAN
        Write-Host "Estimated time remaining (current speed): $remaining_time_current_formatted" -ForegroundColor $colors.CYAN
        Write-Host "Estimated time remaining (average speed): $remaining_time_avg_formatted" -ForegroundColor $colors.CYAN
        Write-Host "------------------------------------"
        Draw-VerticalGraph $speed_data

        $previous_size_bytes = $processed_size_bytes
        $previous_time = $current_time
    } else {
        Write-Host "File not found: $file_path" -ForegroundColor $colors.RED
    }

    Write-Host "------------------------------------"

    [Console]::CursorVisible = $true
    Start-Sleep -Seconds 1
}
