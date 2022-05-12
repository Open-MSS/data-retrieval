#!/bin/bash
read -p "Enter job-id :" jobid
sacct --format="CPUTime,MaxRSS,MaxVMSize" -j $jobid
