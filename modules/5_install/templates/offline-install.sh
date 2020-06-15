#!/bin/bash
xfs_growfs /dev/vda2
mkdir -p /opt/registry/{auth,certs,data}
cd /opt/registry/certs
sudo firewall-cmd --permanent --zone=public --add-port=5000/tcp
sudo firewall-cmd --reload
sudo podman pull ibmcom/registry-ppc64le:2.6.2.5
openssl req -newkey rsa:4096 -nodes -sha256 -keyout domain.key -x509 -days 365 -out domain.crt -subj "/C=US/ST=State/L=City/O=Company, Inc./OU=Department Name/CN=local-registry.apps.${cluster_id}.${cluster_domain}"
htpasswd -bBc /opt/registry/auth/htpasswd admin admin
podman run --name mirror-registry -p 5000:5000 -v /opt/registry/data:/var/lib/registry:z -v /opt/registry/auth:/auth:z -e "REGISTRY_AUTH=htpasswd" -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd -v /opt/registry/certs:/certs:z -e  REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key -d  ibmcom/registry-ppc64le:2.6.2.5
cp /opt/registry/certs/domain.crt /etc/pki/ca-trust/source/anchors/
update-ca-trust
sudo podman login -u admin -p admin --authfile /root/pullsecret_config.json  local-registry.apps.${cluster_id}.${cluster_domain}:5000
oc adm -a ${local_registry_json} release mirror \
--from=quay.io/${product_repo}/${release_name}:${ocp_release} --to=local-registry.apps.${cluster_id}.${cluster_domain}:5000/${local_repository} \
--to-release-image=local-registry.apps.${cluster_id}.${cluster_domain}:5000/${local_repository}:${ocp_release}



