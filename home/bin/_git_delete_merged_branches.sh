#!/bin/bash


git checkout main

git pull origin main

echo "SHOW branches that are merged to main"
git branch --merged | grep -v "\*" | grep -v "main"

read -p "Hit enter to delete those branches"
git branch --merged | grep -v "\*" | grep -v "main" | xargs -r git branch -d
