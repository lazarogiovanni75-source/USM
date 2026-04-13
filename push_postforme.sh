#!/bin/bash
cd /home/runner/app
git add -A
git commit -m "Add Postforme connection status indicator to dashboard

- Added connection_status method to PostformeService to check API connectivity
- Created shared postforme status indicator component with three states:
  - Connected (green, shows profile count)
  - Error (red, with link to fix)
  - Unconfigured (yellow, with link to connect)
- Added status indicator to dashboard header
- Added status indicator to social account connections page"
git push origin master