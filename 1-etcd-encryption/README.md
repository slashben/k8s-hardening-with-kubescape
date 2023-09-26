# ETCD encryption

## Background

In the realm of Kubernetes, etcd plays a pivotal role. Serving as the consistent and highly-available data store for all network configurations, state information, and secrets, it is integral to the Kubernetes cluster. Thus, when deliberating on the cluster's security, the importance of encrypting the contents of etcd cannot be overemphasized.

Understanding the nature of etcd is key. At its core, etcd holds not just configurations, but critically sensitive information, including secrets and credentials. The integrity and confidentiality of this data are paramount. A compromise not only risks exposure of secrets but also jeopardizes the very operation and stability of the entire Kubernetes cluster.

Beyond the operational perspective, many industries are subject to strict regulatory requirements pertaining to data security. Encrypting data at rest, such as that in etcd, is often a requisite to meet these regulatory standards. Compliance, thus, mandates the need for encryption, ensuring organizations avoid legal ramifications and potential penalties.

In the cybersecurity landscape, adopting a layered defense strategy is a widely recognized best practice. Even if a Kubernetes deployment boasts network isolation, robust access controls, and other security mechanisms, adding encryption to etcd introduces an additional, crucial layer of defense. This ensures that, in the event of inadvertent data access or backup exposures, the underlying data remains unintelligible and secure.

To optimize security, maintaining the encrypted state of etcd is imperative. It acts as both a safeguard against potential threats and a measure to ensure regulatory compliance. As Kubernetes clusters continue to proliferate in both complexity and importance, prioritizing the encryption of etcd is not just recommended; it is essential for robust and secure deployments.

## Testing the current state

Please install [Kubescape](https://github.com/kubescape/kubescape#getting-started)

Then run
```bash
kubescape scan control C-0066
```
If your results show failure, this means that you should configure your cluster to encrypt ETCD
```
┌──────────┬────────────────────────────────┬──────────────────┬───────────────┬────────────────────┐
│ SEVERITY │          CONTROL NAME          │ FAILED RESOURCES │ ALL RESOURCES │ % COMPLIANCE-SCORE │
├──────────┼────────────────────────────────┼──────────────────┼───────────────┼────────────────────┤
│ Medium   │ Secret/ETCD encryption enabled │        1         │       1       │        0%          │
├──────────┼────────────────────────────────┼──────────────────┼───────────────┼────────────────────┤
│          │        RESOURCE SUMMARY        │        1         │       1       │      0.00%         │
└──────────┴────────────────────────────────┴──────────────────┴───────────────┴────────────────────┘
```

## Encrypt your ETCD

Here we will show why an unencrypted ETCD is dangerous, then we will reconfigure the Kubernetes API server to encrypt the contents of the ETCD.

### Minikube

Start your Minikube with the `setup-minikube.sh` that can be found in the root of this repository.

This makes sure  that all the needed configurations are in place.

### Reveal your secret

Let's create a secret, run the following command:

```bash
kubectl create secret generic some-secret --from-literal=token=youshouldnotseeme
```

Now this secret has been added to our cluster and it is stored in the ETCD by the API Server.

Since our API Server is not configured to encrypt secrets, anyone who has access to the ETCD API, to the RAM, or its storage will have access the the contents of the secret.

Run this example:

```bash
kubectl exec -n kube-system etcd-minikube -- \
 etcdctl \
 --cacert /var/lib/minikube/certs/etcd/ca.crt \
 --cert /var/lib/minikube/certs/etcd/server.crt \
 --key /var/lib/minikube/certs/etcd/server.key \
 get /registry/secrets/default/some-secret
```
```
some-secretdefault"*$a5c9608c-0118-4bfe-a5dc-83a50c6792472��ɨ�b
kubectl-createUpdatev��ɨFieldsV1:.
,{"f:data":{".":{},"f:token":{}},"f:type":{}}B
tokenyoushouldnotseemeOpaque"
```

As you can see, the *youshouldnotseeme* secret value is there in clear text.

### Configure API Server for ETCD encryption

API Server will encrypt secrets if we provide an encryption configuration at is startup in the command line arguments.

#### Configuration file

First, let's create an encryption configuration file. You can find an [example](encryption-conf.yaml) in this directory. You should replace the secret with your own in the list of keys (see `key1` in the example). It is a base64 encoded 32 byte key. Run this to get your own random key:

```bash
head -c 32 /dev/urandom | base64
```

Save the configuration file and place it somewhere under your home directory.

#### Adding configuration file to the node

Now we need to place this file on the node which runs the API Server.

In our case Minikube is running with a single node and we have mapped the home directory inside (`--mount=true` in the `setup-minikube.sh` file).

We have to open a shell on the node, create a directory under `/etc/kubernetes` and copy the configuration there (**note:** replace `projects/k8s-hardening-with-kubescape/1-etcd-encryption` bellow with the directory under which you put your `encryption-conf.yaml`):

```bash
minikube ssh
sudo mkdir /etc/kubernetes/encryption
sudo cp /minikube-host/projects/k8s-hardening-with-kubescape/1-etcd-encryption/encryption-conf.yaml /etc/kubernetes/encryption/.
```

#### Reconfiguring API Server

Kubernetes API server runs as a static Pod on a Minikube. Therefore to change its configuration, we need to edit the YAML file where it is defined directly.

While still in the shell of the node, use `vi` (or other editor, you might need to install them with `apt`) to add the following lines to the `/etc/kubernetes/manifests/kube-apiserver.yaml` file to change API Server configuration.

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: kube-apiserver
  namespace: kube-system
spec:
  containers:
  - command:
    - kube-apiserver
    ...
    - --encryption-provider-config=/etc/kubernetes/enc/encryption-conf.yaml
    ...
    volumeMounts:
    ...
    - mountPath: /etc/kubernetes/enc
      name: enc-vol
      readOnly: true
  ...
  volumes:
  ...
  - hostPath:
      path: /etc/kubernetes/encryption
      type: DirectoryOrCreate
    name: enc-vol
status: {}
```

Note that:
1. We mounted the `encryption` directory from the node
2. Changed the command line parameters of the API Server to point to the encryption configuration


After the file is changed, Kubelete will try to bring up API Server again, it might take 2 minutes or so. Test the new configuration by leaving the node shell and running `kubectl get pods` to see that the API server answers correctly.

#### Validating encryption

Now running Kubescape again we should see that the test passes:

```bash
kubescape scan control C-0066
```
```
┌──────────┬────────────────────────────────┬──────────────────┬───────────────┬────────────────────┐
│ SEVERITY │          CONTROL NAME          │ FAILED RESOURCES │ ALL RESOURCES │ % COMPLIANCE-SCORE │
├──────────┼────────────────────────────────┼──────────────────┼───────────────┼────────────────────┤
│ Medium   │ Secret/ETCD encryption enabled │        0         │       1       │        100%        │
├──────────┼────────────────────────────────┼──────────────────┼───────────────┼────────────────────┤
│          │        RESOURCE SUMMARY        │        0         │       1       │      100.00%       │
└──────────┴────────────────────────────────┴──────────────────┴───────────────┴────────────────────┘
```

Now testing it by reading secrets directly like before. Creating another secret:
```bash
kubectl create secret generic some-other-secret --from-literal=token=youshouldnotseeme
```

Let's try to read it directly:
```bash
kubectl exec -n kube-system etcd-minikube --  \
 etcdctl  \
 --cacert /var/lib/minikube/certs/etcd/ca.crt  \
 --cert /var/lib/minikube/certs/etcd/server.crt \
 --key /var/lib/minikube/certs/etcd/server.key \
 get /registry/secrets/default/some-other-secret
```
```
�]��O�[������s�.�������D'ɧFZ��E0���H�G*��҄�?�j���C����3GH>Ժu��Z%0����8C�ǲyw+":���2��gp����{:��!�R��E��E"���,�h
                                                                        �۞�֝��j)����^�;�?[�d�=��(�SKw� ��
                                                                                                        y%��Y94Ә���<�V�o������KY�[XSw���`h
```

Voila! 😎





