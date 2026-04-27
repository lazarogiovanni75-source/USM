#!/bin/bash
cd /home/runner/app
git add app/controllers/sessions_controller.rb
git commit -m "Remove privacy mode check blocking login"
git push origin master
