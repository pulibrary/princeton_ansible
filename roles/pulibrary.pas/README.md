# Princeton and Slavery Build Routine

## Optional Global ansible variables

If the following are not supplied the application will be installed assuming it is a vagrant installation intended for local development.

* application_server - Name or IP of server application will run on. Ex: my-prod-hostname.princeton.edu
* application_site_url - Public URL of site. Ex: https://myappname.princeton.edu.
* application_base_url - Base URL of public site. Typically the same as applciation_site_url unless installed at a non-root path.
