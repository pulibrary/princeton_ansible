#!/bin/bash
systemctl start @{1..{{resque_worker_count}}}
