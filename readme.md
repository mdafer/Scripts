# File Progress Monitor

This repository contains two PowerShell and Bash scripts designed to monitor the progress of a file being downloaded or updated in real-time. They display information such as processed size, progress percentage, current speed, average speed, maximum speed seen, and estimated time remaining based on current and average speeds. Additionally, they provide a visual representation of the download speed over time.

## Features

- Displays processed size in GB.
- Shows progress percentage with a progress bar.
- Calculates and displays current speed, average speed, and maximum speed seen.
- Provides estimated time remaining based on current and average speeds.
- Visual representation of download speed over time.
- Clears the screen periodically to maintain readability.

## Screenshot
![Screenshot](screenshot.png?raw=true "Screenshot")

## Usage

### Windows

1. Save the script to a file, for example, `progress.ps1`.
2. Open PowerShell with administrator privileges.
3. Navigate to the directory where you saved `progress.ps1`.
4. Run the script using the following command:
   ```powershell
   .\progress.ps1
### Linux
1. Save the script to a file, for example, progress.sh.
2. Open a terminal.
3. Navigate to the directory where you saved progress.sh.
4. Make the script executable:
    ```bash
    chmod +x progress.sh
5. Run the script using the following command:
    ```bash
    ./progress.sh
## Note
This is a quick script created with the assistance of ChatGPT for personal use, so bugs may exist here and there, but it does the job.