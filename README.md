<p style="text-align: center;">
<img src="https://developers.redhat.com/blog/wp-content/uploads/2018/10/Untitled-drawing-4.png" data-canonical-src="https://developers.redhat.com/blog/wp-content/uploads/2018/10/Untitled-drawing-4.png" width="300" />
<img src="https://developers.redhat.com/blog/wp-content/uploads/2018/05/strimzilogo_stacked_default_450px.png" data-canonical-src="https://developers.redhat.com/blog/wp-content/uploads/2018/05/strimzilogo_stacked_default_450px.png" width="120" /> 
<br />
<img src="https://openjdk.java.net/images/openjdk.png" data-canonical-src="https://openjdk.java.net/images/openjdk.png" width="180" />
<img src="https://camel.apache.org/_/img/logo-camel-medium.png" data-canonical-src="https://camel.apache.org/_/img/logo-camel-medium.png" width="180" />
<img src="https://wiki.postgresql.org/images/3/30/PostgreSQL_logo.3colors.120x120.png" data-canonical-src="https://wiki.postgresql.org/images/3/30/PostgreSQL_logo.3colors.120x120.png" width="80" />
<img src="https://quarkus.io/assets/images/quarkus_logo_horizontal_rgb_600px_reverse.png" data-canonical-src="https://quarkus.io/assets/images/quarkus_logo_horizontal_rgb_600px_reverse.png" width="500" />
</p>

# Acrostic Demo

### The purpose of this demo is to utilize the components within the Red Hat Integration and Runtimes portfolio to integrate a traditional application with a microservices based architecture on OpenShift. 

---
 
**Note:** The following instructions deploy AMQ Streams leveraging the Red Hat AMQ Streams operator. Additionally, it deploys a Java application that leverages Kafka with a built-in consumer and producer. It is capable of sending messages to AMQ Streams using REST endpoints

## Login to OCP via oc client (Download from the Assets section located [here](https://github.com/openshift/okd/releases/tag/4.4.0-0.okd-2020-03-28-092308))
```sh
oc login <cluster_url>
```
---
# Automated install

1. Download and run the "run-acrostic.sh" script:
```sh
. ./run-acrostic.sh
```

**DONE! Now, you can access the Acrostic Quarkus UI by clicking the route for the "quarkus-kafka-consumer" microservice.**
---
# Manual install

## Install and deploy AMQ Streams:

1. Create new project called "kafka-demo"
```sh
oc new-project kafka-demo
```

2. Create AMQ Streams Operator Subscription:
```sh
echo '{"apiVersion":"operators.coreos.com/v1alpha1","kind":"Subscription","metadata":{"name":"amq-streams","namespace":"openshift-operators"},"spec":{"channel":"stable","installPlanApproval":"Automatic","name":"amq-streams","source":"redhat-operators","sourceNamespace":"openshift-marketplace","startingCSV":"amqstreams.v1.5.3"}}' | \
oc apply -f -
```
**Wait about 30 seconds for the Operator to be installed in the openshift-operators namespace, and then:**

3. Deploy Kafka cluster:
```sh
echo '{"apiVersion":"kafka.strimzi.io/v1beta1","kind":"Kafka","metadata":{"name":"my-cluster","namespace":"kafka-demo"},"spec":{"kafka":{"config":{"offsets.topic.replication.factor":3,"transaction.state.log.replication.factor":3,"transaction.state.log.min.isr":2,"log.message.format.version":"2.5"},"version":"2.5.0","storage":{"type":"ephemeral"},"replicas":3,"listeners":{"plain":{"authentiation":{"type":"scram-sha-512"}},"tls":{"authentiation":{"type":"tls"}}}},"entityOperator":{"topicOperator":{"reconciliationIntervalSeconds":90},"userOperator":{"reconciliationIntervalSeconds":120}},"zookeeper":{"storage":{"type":"ephemeral"},"replicas":3}}}' | \
oc apply -f -
```

**Wait about 60 seconds for the resources to be created in the kafka-demo project, and then:**

## Deploy demo components:

1. Extract ca.crt from the Kafka cluster install for TLS configuration:
```sh 
oc extract secret/my-cluster-cluster-ca-cert --keys=ca.crt --confirm=true -n kafka-demo
```

2. Create new project called "acrostic-demo":
```sh
oc new-project acrostic-demo
```

3. Create ConfigMap from the local ca.crt file created on step 4:
```sh
oc create configmap kafka-cert --from-file=./ca.crt -n acrostic-demo
```

### Deploy the JEE static XML app on Jboss EAP:
1. Deploy the application:
```sh
oc new-app jboss-eap72-openshift:latest~https://github.com/roller1187/random-message-generator.git \
    -l app.openshift.io/runtime=eap \
    -n acrostic-demo
```

2. Create ingress route:
```sh
oc expose svc/random-message-generator -n acrostic-demo --path /xml
```
<sub>Source repo: [random-message-generator](https://github.com/roller1187/random-message-generator)
</sub>

### Deploy the PostgreSQL database:
1. Deploy the application:
```sh
oc new-app --name postgresql \
    -e POSTGRESQL_USER=openshift \
    -e POSTGRESQL_PASSWORD=openshift \
    -e POSTGRESQL_DATABASE=sampledb \
    registry.access.redhat.com/rhscl/postgresql-10-rhel7 \
    -l app.openshift.io/runtime=postgresql \
    -n acrostic-demo
```

### Deploy the Kafka Consumer microservice using OpenJDK:
1. Deploy the application:
```sh
oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/kafka-consumer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env KAFKA_UI_TOPIC=ui-topic \
    --env KAFKA_PRODUCER_URL=http://kafka-producer.acrostic-demo.svc.cluster.local:8080 \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    --env POSTGRES_SERVICE_URL=postgresql.acrostic-demo.svc.cluster.local:5432/sampledb \
    -l app.openshift.io/runtime=openjdk \
    -n acrostic-demo
```

2. Create a volume mapping to auto-generate keystore from Kafka certificate
```sh
oc set volume deployment/kafka-consumer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo
```
<sub>Source repo: [kafka-consumer](https://github.com/roller1187/kafka-consumer)
</sub>

### Deploy the Kafka Producer microservice using OpenJDK:
1. Deploy the application:
```sh
oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/kafka-producer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=openjdk \
    -n acrostic-demo
```

2. Create a volume mapping to auto-generate keystore from Kafka certificate
```sh
oc set volume deployment/kafka-producer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo
```

3. Create ingress route:
```sh
oc expose svc/kafka-producer -n acrostic-demo
```
<sub>Source repo: [kafka-producer](https://github.com/roller1187/kafka-producer)
</sub>

### Deploy the Fuse Kafka Producer microservice using OpenJDK:
1. Deploy the application:
```sh
oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/fuse-kafka-producer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=camel \
    -n acrostic-demo
```

2. Create a volume mapping to auto-generate keystore from Kafka certificate
```sh
oc set volume deployment/fuse-kafka-producer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo
```
<sub>Source repo: [fuse-kafka-producer](https://github.com/roller1187/fuse-kafka-producer)
</sub>

### Deploy the Quarkus Kafka Consumer microservice using OpenJDK:

1. Deploy the application:
```sh
oc new-app openjdk-11-rhel8:1.0~https://github.com/roller1187/quarkus-kafka-consumer.git \
    --env=JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0" \
    --env=KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=quarkus \
    -n acrostic-demo
```

2. Create volume mappings to auto-generate keystore from Kafka certificate
```sh
oc set volume --name kafka-cert deployment/quarkus-kafka-consumer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo
```
```sh
oc set volume --name keystore deployment/quarkus-kafka-consumer --add --type=emptyDir --mount-path=/tmp -n acrostic-demo
```

3. Export Deployment Config into local file quarkus-deployment.yml:
```sh
oc get deployment/quarkus-kafka-consumer --output=yaml > ./quarkus-deployment.yml
```

4. Edit Deployment Config to add initContainer for keystore creation (sed dependency):
```sh
sed -i '' 's/^      containers:/      initContainers: \
        - name: init-createkeystore \
          image: '\''registry.redhat.io\/openjdk\/openjdk-11-rhel7:1.0'\'' \
          command: \
            - keytool \
            - '\''-import'\'' \
            - '\''-file'\'' \
            - \/tmp\/certs\/ca.crt \
            - '\''-keypass'\'' \
            - password \
            - '\''-keystore'\'' \
            - \/tmp\/keystore.jks \
            - '\''-storepass'\'' \
            - password \
            - '\''-noprompt'\'' \
          volumeMounts: \
            - name: kafka-cert \
              mountPath: \/tmp\/certs \
            - name: keystore \
              mountPath: \/tmp \
&/g' quarkus-deployment.yml
```

5. Apply Deployment Config changes:
```sh
oc apply -f ./quarkus-deployment.yml
```

6. Create ingress route:
```sh
oc expose svc/quarkus-kafka-consumer -n acrostic-demo
``` 
<sub>Source repo: [quarkus-kafka-consumer](https://github.com/roller1187/quarkus-kafka-consumer)
</sub>

**DONE! Now, you can access the Acrostic Quarkus UI by clicking the route for the "quarkus-kafka-consumer" microservice.**

## Enjoy!

---
# Other resources

## For PostgreSQL port forwarding from OCP cluster to localhost:80 In order to access DB using pgAdmin
1. From your terminal logged into OCP, execute the following command:
```sh
sudo oc port-forward $(oc get pods -n acrostic-demo | grep postgresql | grep Running | awk '{print $1}') 80:5432
```

2. Run pgAdmin from your local server and connect to the database running on OCP using server address "localhost" on port 80. Database username/password: "openshift/openshift"

## To remove this demo and all of its components, run:
```sh
oc delete all --selector app=kafka-consumer -n acrostic-demo
oc delete all --selector app=kafka-producer -n acrostic-demo
oc delete all --selector app=fuse-kafka-producer -n acrostic-demo
oc delete all --selector app=quarkus-kafka-consumer -n acrostic-demo
oc delete all --selector app=random-message-generator -n acrostic-demo
oc delete all --selector app=postgresql -n acrostic-demo
oc delete all --selector app.kubernetes.io/instance=my-cluster -n kafka-demo
oc delete subscription amq-streams -n openshift-operators
oc delete ClusterServiceVersion amqstreams.v1.5.3 -n default
oc delete project acrostic-demo
oc delete project kafka-demo
```

---
Please create any issues against this project and feel free to contribute!
