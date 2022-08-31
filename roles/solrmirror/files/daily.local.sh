dir=/var/www/htdocs/solrmirror/dist/lucene
uri=rsync.us.apache.org
path=apache-dist/lucene/solr

cd $dir
/usr/local/bin/rsync -avz $uri::$path/ solr/
