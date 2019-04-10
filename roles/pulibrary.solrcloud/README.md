## SolrCloud

This role will install [SolrCloud](https://cwiki.apache.org/confluence/display/solr/SolrCloud) on at least 3 endpoints listed in your inventory file or three VMs as listed in your Vagrantfile.

## SolrCloud Staging Cluster
The SolrCloud Staging Cluster does not have a shared network backup configured. In order to successfully run the play book run the following command:
```
ansible-playbook playbooks/solrcloud_staging.yml --skip-tags mnt
```
