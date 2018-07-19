## Openshift Origin 证书替换
  - [Etcd证书](#etcd)
    + [Etcd服务器端证书](#etcd-server)
    + [Etcd客户端证书](#etcd-client)
    + [Etcd CA证书](#etcd-ca)
  - [Registry证书](#registry)
  - [Router证书](#router)
  - [~~Webconsole证书~~](#webconsole)
  - [Openshift证书](#openshift)
    + [Openshift主控证书](#openshift-master)
    + [Openshift节点证书](#openshift-node)
    + ~~[Openshift CA证书](#openshift-ca)~~

### Etcd

#### Etcd Server

证书列表
```liquid
/etc/etcd/peer.crt
/etc/etcd/peer.csr
/etc/etcd/peer.key
/etc/etcd/server.crt
/etc/etcd/server.csr
/etc/etcd/server.key
```

在etcd CA host (有 /etc/etcd/ca/ca.crt 的主机) 上执行
```bash
// 重新生成etcd server证书
# ./gen-etcd-server-certificate.sh

// 更新etcd server证书
// 重启etcd server
# ./update-etcd-server-certificate.sh
```

#### Etcd Client

证书列表
```liquid
/etc/origin/master/master.etcd-ca.crt
/etc/origin/master/master.etcd-client.csr
/etc/origin/master/master.etcd-client.crt
/etc/origin/master/master.etcd-client.key
```

在etcd CA host (有 /etc/etcd/ca/ca.crt 的主机) 上执行
```bash
// 重新生成etcd client证书
# ./gen-etcd-client-certificate.sh

// 更新etcd client证书
// 重启origin master
# ./update-etcd-client-certificate.sh 
```

#### Etcd CA

证书列表
```liquid
/etc/etcd/ca/ca.crt
/etc/etcd/ca/ca.key
/etc/etcd/ca/serial
/etc/etcd/ca/index.txt
/etc/etcd/ca/openssl.cnf
```

在etcd CA host (有 /etc/etcd/ca/ca.crt 的主机) 上执行
```bash
// 重新生成etcd CA证书
# ./gen-etcd-ca-certificate.sh

// 更新etcd CA证书 (注意这里没有重启etcd server)
# ./update-etcd-ca-certificate.sh

// 立即用新的CA重新生成和替换etcd server 和etcd client 相关证书

# ./gen-etcd-server-certificate.sh        // 重新生成etcd server证书
# ./update-etcd-server-certificate.sh     // 更新etcd server证书，并重启etcd server
# etcdctl2 ls /                           // 验证etcd server正常
# oc get nodes                            // 验证此时openshift master无法访问etcd server
Error from server (Timeout): the server was unable to return a response in the time allotted, but may still be processing the request (get nodes)

# ./gen-etcd-client-certificate.sh        // 重新生成etcd client证书
# ./update-etcd-client-certificate.sh     // 更新etcd client证书，并重启origin master
# oc get nodes                            // 验证openshift master正常
```

### Registry

证书列表
```liquid
/etc/origin/master/registry.crt
/etc/origin/master/registry.key
```

相关Secret
```bash
# oc describe -n default secret/registry-certificates
```

在openshift CA host (有 /etc/origin/master/ca.crt 的主机) 上执行
```bash
// 重新生成registry证书
# ./gen-registry-certificate.sh

// 更新registry证书
// 重建secret/registry-certificates
// 滚动更新dc/docker-registry
# ./update-registry-certificate.sh         

验证新的registry证书
# curl -k -v https://$(oc get service/docker-registry -n default -o json  | jq ".spec.clusterIP" | tr -d '"'):5000
```

### Router

证书列表
```liquid
/etc/origin/master/openshift-router.crt
/etc/origin/master/openshift-router.key
```

相关Secret
```bash
# oc describe -n default secret/router-certs
```

在openshift CA host (有 /etc/origin/master/ca.crt 的主机) 上执行
```bash
// 重新生成router证书 
// 第一个参数是基础域名, 这里传参dmos.dataman,根据实际情况修改
# ./gen-router-certificate.sh  dmos.dataman     

// 更新router证书
// 重建secret/router-certs
// 滚动更新dc/router
# ./update-router-certificate.sh                

// 验证新的router证书
# curl -k -v https://$(oc get service/router -n default -o json  | jq ".spec.clusterIP" | tr -d '"'):443
```

### ~~Webconsole~~

### Openshift

#### Openshift Master 

证书列表
```liquid
/etc/origin/master/master.server.crt
/etc/origin/master/master.server.key
/etc/origin/master/openshift-master.crt
/etc/origin/master/openshift-master.key
/etc/origin/master/openshift-master.kubeconfig
```

在openshift CA host (有 /etc/origin/master/ca.crt 的主机) 上执行
```bash
// 重新生成openshift master 和 loopback client证书
// 第一个参数是master证书的访问域名
// 第二个参数是master loopback API URL
./gen-openshift-master-certificate.sh  master231.dmos.dataman  https://master231.dmos.dataman:8443   

// 更新openshift master 和 loopback client证书
// 重启openshift master
# ./update-openshift-master-certificate.sh
```

#### Openshift Node

证书列表
```liquid
/etc/origin/node/server.crt
/etc/origin/node/server.key
/etc/origin/node/system:node:{hostname}.key
/etc/origin/node/system:node:{hostname}.crt
/etc/origin/node/system:node:{hostname}.kubeconfig
```

在openshift CA host (有 /etc/origin/master/ca.crt 的主机) 上执行
```bash
// 重新生成openshift master 和 loopback client证书
// 第一个参数是openshift node节点的主机名
// 第二个参数是openshift master的API URL
./gen-openshift-node-certificate.sh  node234.dmos.dataman https://master231.dmos.dataman:8443

// 把生成的节点证书通过scp分发到对应节点的/etc/origin/node/目录下
# scp /etc/openshift-generated-certs/origin/node/node234.dmos.dataman/* root@node234.dmos.dataman:/etc/origin/node/
```

在更新节点证书的节点上执行
```bash
// 重启origin-node 服务
# systemctl  restart origin-node
```

回到openshift master上验证节点正常
```bash
# oc get nodes/node234.dmos.dataman
```

#### ~~Openshift CA~~
