![Strimzi](https://developers.redhat.com/blog/wp-content/uploads/2018/05/strimzilogo_stacked_default_450px.png =250x250)

<img src="https://developers.redhat.com/blog/wp-content/uploads/2018/05/strimzilogo_stacked_default_450px.png" data-canonical-src="https://developers.redhat.com/blog/wp-content/uploads/2018/05/strimzilogo_stacked_default_450px.png" width="200" height="400" />

# Kafka Workshop

### The purpose of this workshop is to utilize the components within the Red Hat Integration portfolio to integrate a traditional application with more applications within OpenShift through kafka. 

---

## The instructions below should be completed by the instructor to demonstrate the deployment of Kafka as a centralized service
 
**Note:** The following instructions deploy AMQ Streams leveraging the Strimzi operator. Additionally, it deploys a Java application that leverages Kafka with a built-in consumer and producer. It is capable of sending messages to AMQ Streams using REST endpoints

## To install AMQ Streams:

1) Clone the openshift-workshop repository from GitHub:
```sh
git clone https://github.com/roller1187/kafka-workshop.git
```

2) Change directory to inside the repository:
```sh
cd ./kafka-workshop
```

3) Login to OpenShift:
```sh
oc login <cluster URL>
```
4) Create a new project:
```sh 
oc new-project kafka
```

5) Load the new project:
```sh
oc project kafka
```

6) Configure access for the Strimzi operator namespace:
```sh
oc adm policy add-cluster-role-to-user strimzi-cluster-operator-namespaced --serviceaccount strimzi-cluster-operator -n kafka

oc adm policy add-cluster-role-to-user strimzi-entity-operator --serviceaccount strimzi-cluster-operator -n kafka

oc adm policy add-cluster-role-to-user strimzi-topic-operator --serviceaccount strimzi-cluster-operator -n kafka
```

7) Deploy all the configuration for the cluster operator:
```sh
oc apply -f ./install/cluster-operator/
```
## To configure Kafka:

1) Create Kafka brokers and Zookeeper instances:
```sh
oc apply -f ./setup/my-cluster.yaml
```

**Wait until all 3 replicas of Kafka and Zookeeper are online**

## Deploy workshop components:

1. Deploy Kafka Acrostic consumer service:
[kafka-consumer](https://github.com/roller1187/kafka-consumer)

2. Deploy Kafka producer service:
[kafka-producer](https://github.com/roller1187/kafka-producer)

3. Deploy Fuse Kafka producer service:
[fuse-kafka-producer](https://github.com/roller1187/fuse-kafka-producer)

4. Deploy a Quarkus UI to visualize the acrostic map:
[quarkus-kafka-consumer](https://github.com/roller1187/quarkus-kafka-consumer)

## Enjoy!
