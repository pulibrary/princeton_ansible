#!/bin/bash
systemctl start appdeploy-workers@{1..{{resque_worker_count}}}
