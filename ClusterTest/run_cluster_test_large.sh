#!/bin/bash

echo "This script run inside of the docker container."

echo "Below variables must be set by workflow and docker-conpose file"
echo "GITHUB_RUN_ID=$GITHUB_RUN_ID"
echo "GITHUB_SHA=$GITHUB_SHA"
echo "TEST_SPARK_CONNECTOR_VERSION=$TEST_SPARK_CONNECTOR_VERSION"
echo "TEST_SCALA_VERSION=$TEST_SCALA_VERSION"
echo "TEST_COMPILE_SCALA_VERSION=$TEST_COMPILE_SCALA_VERSION"
echo "TEST_JDBC_VERSION=$TEST_JDBC_VERSION"
echo "TEST_SPARK_VERSION=$TEST_SPARK_VERSION"
echo "SNOWFLAKE_TEST_CONFIG=$SNOWFLAKE_TEST_CONFIG"

export SPARK_HOME=/users/spark
export SPARK_WORKDIR=/users/spark/work

export SPARK_CONNECTOR_JAR_NAME=spark-snowflake_${TEST_SCALA_VERSION}-${TEST_SPARK_CONNECTOR_VERSION}-spark_${TEST_SPARK_VERSION}.jar
export JDBC_JAR_NAME=snowflake-jdbc-${TEST_JDBC_VERSION}.jar

# Check test file exists
ls -al $SNOWFLAKE_TEST_CONFIG \
       $SPARK_WORKDIR/${SPARK_CONNECTOR_JAR_NAME} \
       $SPARK_WORKDIR/${JDBC_JAR_NAME} \
       $SPARK_WORKDIR/clustertest_${TEST_SCALA_VERSION}-1.0.jar \
       $SPARK_WORKDIR/ClusterTest.py

echo "Important: if new test cases are added, script .github/workflow/ClusterTest*.yml MUST be updated"

for i in {1..10}
do
  (
    $SPARK_HOME/bin/spark-submit \
        --jars $SPARK_WORKDIR/${SPARK_CONNECTOR_JAR_NAME},$SPARK_WORKDIR/${JDBC_JAR_NAME} \
        --conf "spark.executor.extraJavaOptions=-Djava.io.tmpdir=$SPARK_WORKDIR  -Dnet.snowflake.jdbc.loggerImpl=net.snowflake.client.log.SLF4JLogger -Dlog4j.configuration=file://${SPARK_HOME}/conf/log4j_executor.properties" \
        --conf "spark.driver.extraJavaOptions=-Djava.io.tmpdir=$SPARK_WORKDIR -Dnet.snowflake.jdbc.loggerImpl=net.snowflake.client.log.SLF4JLogger -Dlog4j.configuration=file://${SPARK_HOME}/conf/log4j_driver.properties" \
        --executor-memory 600m \
        --total-executor-cores 1 \
        --master spark://master:7077 --deploy-mode client \
        --class net.snowflake.spark.snowflake.ClusterTest \
        $SPARK_WORKDIR/clustertest_${TEST_SCALA_VERSION}-1.0.jar remote "net.snowflake.spark.snowflake.testsuite.HighConcurrencySuite;"
    echo "$(date) Job $i finished execution"
  ) &
  pids[${i}]=$!
  echo "$(date) Submitted job $i"
done

# wait for all pids
for pid in ${pids[*]}; do
  wait $pid
done