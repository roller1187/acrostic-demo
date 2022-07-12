#!/bin/bash

# Install Kafka

echo '{"apiVersion":"operators.coreos.com/v1alpha1","kind":"Subscription","metadata":{"name":"amq-streams","namespace":"openshift-operators"},"spec":{"channel":"stable","installPlanApproval":"Automatic","name":"amq-streams","source":"redhat-operators","sourceNamespace":"openshift-marketplace","startingCSV":"amqstreams.v2.1.0-5"}}' | \
oc apply -f -

echo Waiting 30 secs for Kafka to be installed...
sleep 30

oc new-project kafka-demo

echo '{"apiVersion":"kafka.strimzi.io/v1beta2","kind":"Kafka","metadata":{"name":"my-cluster","namespace":"kafka-demo"},"spec":{"kafka":{"config":{"offsets.topic.replication.factor":3,"transaction.state.log.replication.factor":3,"transaction.state.log.min.isr":2,"default.replication.factor":3,"min.insync.replicas":2,"inter.broker.protocol.version":"3.1"},"version":"3.1.0","storage":{"type":"ephemeral"},"replicas":3,"listeners":[{"name":"plain","port":9092,"type":"internal","tls":false},{"name":"tls","port":9093,"type":"internal","tls":true}]},"entityOperator":{"topicOperator":{},"userOperator":{}},"zookeeper":{"storage":{"type":"ephemeral"},"replicas":3}}}' | \
oc apply -f -

echo Waiting 60 secs for Kafka to be deployed...
sleep 60

oc extract secret/my-cluster-cluster-ca-cert --keys=ca.crt --confirm=true -n kafka-demo

oc new-project acrostic-demo

oc create configmap kafka-cert --from-file=./ca.crt -n acrostic-demo

oc new-app jboss-eap72-openshift:latest~https://github.com/roller1187/random-message-generator.git \
    -l app.openshift.io/runtime=eap \
    -n acrostic-demo

oc expose svc/random-message-generator -n acrostic-demo --path /xml

oc new-app --name postgresql \
    -e POSTGRESQL_USER=openshift \
    -e POSTGRESQL_PASSWORD=openshift \
    -e POSTGRESQL_DATABASE=sampledb \
    registry.access.redhat.com/rhscl/postgresql-10-rhel7 \
    -l app.openshift.io/runtime=postgresql \
    -n acrostic-demo

oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/kafka-consumer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env KAFKA_UI_TOPIC=ui-topic \
    --env KAFKA_PRODUCER_URL=http://kafka-producer.acrostic-demo.svc.cluster.local:8080 \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    --env POSTGRES_SERVICE_URL=postgresql.acrostic-demo.svc.cluster.local:5432/sampledb \
    -l app.openshift.io/runtime=openjdk \
    -n acrostic-demo

oc set volume deployment/kafka-consumer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo

oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/kafka-producer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=openjdk \
    -n acrostic-demo

oc set volume deployment/kafka-producer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo

oc expose svc/kafka-producer -n acrostic-demo

oc new-app openjdk-11-rhel7:1.0~https://github.com/roller1187/fuse-kafka-producer.git \
    --env KAFKA_BACKEND_TOPIC=my-topic \
    --env SPRING_KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=camel \
    -n acrostic-demo

oc set volume deployment/fuse-kafka-producer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo

oc new-app openjdk-11-rhel8:1.0~https://github.com/roller1187/quarkus-kafka-consumer.git \
    --env=JAVA_OPTIONS="-Dquarkus.http.host=0.0.0.0" \
    --env=KAFKA_BOOTSTRAP_SERVERS=my-cluster-kafka-bootstrap.kafka-demo.svc.cluster.local:9093 \
    -l app.openshift.io/runtime=quarkus \
    -n acrostic-demo

oc set volume --name kafka-cert deployment/quarkus-kafka-consumer --add --type=configmap --configmap-name=kafka-cert --mount-path=/tmp/certs -n acrostic-demo
oc set volume --name keystore deployment/quarkus-kafka-consumer --add --type=emptyDir --mount-path=/tmp -n acrostic-demo

oc get deployment/quarkus-kafka-consumer --output=yaml > ./quarkus-deployment.yml -n acrostic-demo

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

oc apply -f ./quarkus-deployment.yml

oc expose svc/quarkus-kafka-consumer -n acrostic-demo

rm -f ./quarkus-deployment.yml
rm -f ./ca.crt
