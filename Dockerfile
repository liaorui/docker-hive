FROM liaor/hadoop-namenode:2.0.0-hadoop3.2.3-java8 
MAINTAINER ryanrliao <ryanrliao@tencent.com>

ENV JAVA_HOME=/opt/jdk

USER root

RUN apk add tzdata && cp /usr/share/zoneinfo/Asia/Shanghai /etc/localtime \
    && echo Asia/Shanghai > /etc/timezone && apk del tzdata
        RUN apk add --no-cache sudo procps psmisc snappy-dev lz4-dev lzo-dev vim busybox-extras net-tools curl perl

# Allow buildtime config of HIVE_VERSION
ARG HIVE_VERSION
# Set HIVE_VERSION from arg if provided at build, env if provided at run, or default
# https://docs.docker.com/engine/reference/builder/#using-arg-variables
# https://docs.docker.com/engine/reference/builder/#environment-replacement
ENV HIVE_VERSION=${HIVE_VERSION:-3.1.2}

ENV HADOOP_VERSION=3.2.3
ENV SPARK_VERSION=3.2.3

ENV HIVE_HOME /opt/hive
ENV PATH $HIVE_HOME/bin:$PATH
ENV HADOOP_HOME /opt/hadoop-$HADOOP_VERSION
ENV SPARK_HOME=/opt/spark

WORKDIR /opt

#Install Hive and PostgreSQL JDBC
ADD apache-hive-$HIVE_VERSION-bin.tar.gz /opt
RUN ln -s apache-hive-$HIVE_VERSION-bin hive 

#Install Spark
ADD spark-$SPARK_VERSION-bin-hadoop3.2.tgz /opt
RUN ln -s spark-$SPARK_VERSION-bin-hadoop3.2 spark

#log4j-2.7.1 and tez api
RUN rm -f $HIVE_HOME/lib/log4j*jar
RUN rm -f $HIVE_HOME/lib/guava*jar
RUN rm -f $HIVE_HOME/lib/jackson-core-*jar
RUN rm -f $HIVE_HOME/lib/jackson-databind-*jar
RUN rm -f $HIVE_HOME/lib/jackson-annotations-*jar
ADD lib/* $HIVE_HOME/lib/

#Custom configuration goes here
ADD conf/hive-site.xml $HIVE_HOME/conf
#Spark should be compiled with Hive to be able to use it             
#hive-site.xml should be copied to $SPARK_HOME/conf folder
RUN ln -s $HIVE_HOME/conf/hive-site.xml $SPARK_HOME/conf/hive-site.xml
ADD conf/beeline-log4j2.properties $HIVE_HOME/conf
ADD conf/hive-env.sh $HIVE_HOME/conf
ADD conf/hive-exec-log4j2.properties $HIVE_HOME/conf
ADD conf/hive-log4j2.properties $HIVE_HOME/conf
ADD conf/ivysettings.xml $HIVE_HOME/conf
ADD conf/llap-daemon-log4j2.properties $HIVE_HOME/conf

COPY startup.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/startup.sh

COPY entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN adduser -s /bin/bash -h /opt -D hive
RUN chown -R hive:hive /opt
RUN chmod -R g+rwx /opt
RUN chmod u+w /etc/sudoers && sed -i '$a\%hive ALL=NOPASSWD: /usr/sbin/adduser,/bin/su' /etc/sudoers

EXPOSE 10000
EXPOSE 10002

USER hive

ENTRYPOINT ["entrypoint.sh"]
CMD startup.sh
