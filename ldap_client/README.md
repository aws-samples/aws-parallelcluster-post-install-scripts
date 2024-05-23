# OpenLDAP Client configuration

The script postinstall.sh will install OpenLDAP client and configure authentication.
This postinstall script supports **Ubuntu** operating systems.

This instructions assume that you have deployed an OpenLDAP server using https://github.com/aws-samples/awsome-distributed-training/tree/main/1.architectures/6.ldap_server


Include the following in your Scheduling sections of the parallelcluster config:

 CustomActions:
    OnNodeConfigured:
      Sequence:
        - Script: https://raw.githubusercontent.com/aws-samples/aws-parallelcluster-post-install-scripts/main/ldap_client/postinstall.sh
            - SECRET_ARN # LDAP password stored in Secret manager
            - LDAP_IP # OpenLDAP server private ip address
            - AWS_REGION # AWS_REGION of the secret
