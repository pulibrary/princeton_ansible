#!/usr/bin/env bash
exec java -cp /usr/share/java/saxon9he.jar net.sf.saxon.Transform "$@"
