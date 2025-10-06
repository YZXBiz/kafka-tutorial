# 9. Building Data Pipelines

> **In plain English:** A data pipeline is like a water distribution system - it moves resources from sources (reservoirs) to destinations (homes and businesses), handling different flow rates, purification needs, and quality standards along the way.
>
> **In technical terms:** Data pipelines move data between systems using Apache Kafka as a scalable, reliable buffer that decouples producers from consumers while enabling multiple consumption patterns.
>
> **Why it matters:** Every modern business runs on data from multiple systems. Efficient, reliable data pipelines are the circulatory system of data-driven organizations - when they fail, critical business processes grind to halt.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Data Integration Context](#2-data-integration-context)
3. [Pipeline Design Considerations](#3-pipeline-design-considerations)
   - 3.1. [Timeliness](#31-timeliness)
   - 3.2. [Reliability](#32-reliability)
   - 3.3. [Throughput](#33-throughput)
   - 3.4. [Data Formats](#34-data-formats)
   - 3.5. [Transformations](#35-transformations)
   - 3.6. [Security](#36-security)
   - 3.7. [Failure Handling](#37-failure-handling)
   - 3.8. [Coupling and Agility](#38-coupling-and-agility)
4. [Kafka Connect vs Producer/Consumer](#4-kafka-connect-vs-producerconsumer)
5. [Kafka Connect Deep Dive](#5-kafka-connect-deep-dive)
   - 5.1. [Running Connect](#51-running-connect)
   - 5.2. [Connector Examples](#52-connector-examples)
   - 5.3. [Single Message Transformations](#53-single-message-transformations)
   - 5.4. [How Connect Works](#54-how-connect-works)
6. [Alternatives to Kafka Connect](#6-alternatives-to-kafka-connect)
7. [Summary](#7-summary)

---

## 1. Introduction

**In plain English:** Building data pipelines means connecting different systems. Kafka excels at being the middle layer that buffers, routes, and manages data flow.

When people discuss Kafka data pipelines, they typically mean one of two patterns:

**Pattern 1: Kafka as endpoint**
```
System A → Kafka (get data into Kafka)
Kafka → System B (get data out of Kafka)
```

**Pattern 2: Kafka as intermediary**
```
System A → Kafka → System B
(Use Kafka to connect two systems)
```

**Example scenarios:**
- Twitter → Kafka → Elasticsearch
- MongoDB → Kafka → S3
- MySQL → Kafka → Data Warehouse
- IoT Sensors → Kafka → Real-time Dashboard

> **💡 Insight**
>
> Kafka Connect was added in version 0.9 after seeing these patterns repeatedly at LinkedIn and other organizations. Rather than force everyone to solve the same problems, Kafka now provides built-in APIs for data integration.

---

## 2. Data Integration Context

**In plain English:** Think bigger than just "How do I get data from MySQL to Kafka?" Consider the entire data ecosystem and how systems connect over time.

**The evolution of integration mess:**

```
Phase 1: Direct connections
MySQL → App → MongoDB

Phase 2: More connections
MySQL → App A → MongoDB
MySQL → App B → HDFS
PostgreSQL → App C → Elasticsearch
PostgreSQL → App D → MongoDB
...

Phase 3: Integration nightmare
├── Custom pipeline per connection pair
├── No reusable components
├── Each new system requires new integrations
└── Expensive to maintain, blocks innovation
```

**Kafka as integration platform:**

```
Sources:               KAFKA           Destinations:
MySQL ─────┐                      ┌───→ MongoDB
PostgreSQL ┼─→   Unified     ─→   ├───→ Elasticsearch
MongoDB ───┤     Platform         ├───→ HDFS
APIs ──────┤                       ├───→ S3
Files ─────┘                       └───→ Data Warehouse

Benefits:
├── Connect any source to any destination
├── Reusable connectors
├── Standard protocol and format
└── Add systems without modifying others
```

> **💡 Insight**
>
> The value isn't just moving data - it's creating a flexible platform where new data sources and destinations can be added without disrupting existing pipelines. This transforms data integration from project-based work to platform-based infrastructure.

---

## 3. Pipeline Design Considerations

### 3.1. Timeliness

**In plain English:** Different business needs require different speeds - some need data within milliseconds, others can wait until overnight batch processing.

**The spectrum:**
```
Near real-time             Micro-batch            Daily batch
(milliseconds)             (minutes)              (hours)
     ↓                         ↓                       ↓
Fraud detection          Dashboards            Reports
Trading systems          Monitoring            Analytics
```

**How Kafka supports all timeliness requirements:**

```
Producers can write:
├── Continuously (real-time)
├── Every few seconds (micro-batch)
└── Once daily (batch)

Consumers can read:
├── Immediately as data arrives
├── Every hour in batches
└── Once daily

Kafka acts as buffer between different speeds
```

**Example - Same data, different timeliness:**
```
User activity events in Kafka:
├── Real-time fraud detection (reads immediately)
├── Hourly dashboard updates (reads every hour)
└── Daily analytics (reads once at night)

All from same Kafka topic, different consumption patterns
```

> **💡 Insight**
>
> Kafka's decoupling of producers and consumers means you can change timeliness requirements without changing the entire pipeline. Switch from daily to hourly processing? Just change the consumer schedule.

### 3.2. Reliability

**In plain English:** Reliability means ensuring data gets from source to destination, even when servers crash, networks fail, or processes restart.

**Reliability requirements:**
```
Can tolerate loss:
└── Click tracking, metrics

At-least-once:
├── Most business applications
└── Duplicates acceptable, loss not

Exactly-once:
├── Financial transactions
├── Inventory management
└── Any aggregations
```

**How Kafka provides reliability:**

```
Kafka's guarantees:
├── At-least-once out of the box
├── Exactly-once with Connect + transactional APIs
└── Multiple replicas prevent data loss

Connect's contribution:
├── Manages offsets automatically
├── Handles retries intelligently
├── Supports exactly-once for many connectors
└── Provides consistent error handling
```

**End-to-end exactly-once example:**
```
MySQL → Kafka Connect JDBC Source → Kafka
        ↓
    Exactly-once semantics
        ↓
Kafka → Kafka Connect JDBC Sink → PostgreSQL
        ↓
    Idempotent writes (upsert based on primary key)
        ↓
    Each MySQL record arrives exactly once in PostgreSQL
```

### 3.3. Throughput

**In plain English:** Pipelines must handle both normal load and traffic spikes without breaking or requiring constant capacity adjustments.

**Kafka's throughput advantages:**

**1. Acts as buffer**
```
Without Kafka:
Producer (100 MB/s) → Consumer (10 MB/s)
└── Back pressure needed
    └── Complex to implement

With Kafka:
Producer (100 MB/s) → Kafka → Consumer (10 MB/s)
└── Kafka absorbs spike
    └── Consumer catches up later
    └── No back pressure logic needed
```

**2. Scales independently**
```
Add more producers:
└── Kafka scales with partitions

Add more consumers:
└── Consumer group parallelism

Add more brokers:
└── Linear throughput scaling
```

**3. Handles varying throughput**
```
Daily pattern:
06:00-18:00: High traffic (500 MB/s)
18:00-06:00: Low traffic (50 MB/s)

Kafka:
├── Accepts all data during peak
├── Consumers process at steady rate
└── No need to provision for peak everywhere
```

**4. Built-in efficiency**
```
Features that boost throughput:
├── Compression (gzip, lz4, snappy, zstd)
├── Batching (amortizes overhead)
├── Zero-copy transfers
└── Sequential disk I/O
```

> **💡 Insight**
>
> Kafka Connect inherits Kafka's scalability. Connect workers can run on different machines, and tasks can be distributed across workers. Scale by adding workers or increasing task parallelism.

### 3.4. Data Formats

**In plain English:** Different systems speak different languages for data. Pipelines must translate between XML, JSON, Avro, Parquet, CSV, and binary formats.

**The format challenge:**
```
Source                  Kafka              Destination
MySQL (SQL rows)   →   Avro format    →   Elasticsearch (JSON)
                       with schema

Requirements:
├── Read MySQL column types correctly
├── Convert to Kafka format (Avro)
├── Store schema for validation
├── Convert from Avro to JSON
└── Write to Elasticsearch
```

**How Kafka Connect handles formats:**

```
Connect's Data API:
├── Internal representation (schema + value)
├── Source connector creates Data API objects
├── Sink connector reads Data API objects
└── Converters translate to/from Kafka storage format

Available converters:
├── JSON (with or without schema)
├── Avro (via Schema Registry)
├── Protobuf (via Schema Registry)
├── JSON Schema (via Schema Registry)
├── String
└── ByteArray
```

**Example format flow:**
```
1. JDBC Source reads MySQL:
   Row { id: 123, name: "Alice", score: 95.5 }
   ↓
2. Convert to Data API:
   Schema: [id: INT, name: STRING, score: DOUBLE]
   Value: {123, "Alice", 95.5}
   ↓
3. Avro converter stores in Kafka:
   Binary Avro format with schema ID
   ↓
4. Avro converter reads from Kafka:
   Back to Data API format
   ↓
5. Elasticsearch sink writes:
   JSON: {"id": 123, "name": "Alice", "score": 95.5}
```

> **💡 Insight**
>
> Converters are configured at the worker level, not per connector. This means you can change the storage format in Kafka without changing any connector code - just update worker configuration.

### 3.5. Transformations

**The great debate: ETL vs ELT**

**ETL (Extract-Transform-Load):**
```
MySQL → Pipeline transforms data → Target system
              ↓
    Filtering, aggregation, enrichment
              ↓
    Only transformed data reaches target

Pros:
├── Saves storage (don't store raw + transformed)
└── Offloads work from expensive target systems

Cons:
├── Pipeline becomes complex
├── Users only see filtered data
└── Changing transformations requires pipeline rebuild
```

**ELT (Extract-Load-Transform):**
```
MySQL → Pipeline minimal transform → Target system
              ↓                           ↓
    Only data type conversion    Full data available
                                         ↓
                              Transform here as needed

Pros:
├── Maximum flexibility for users
├── Can always access raw data
└── Easier to troubleshoot

Cons:
├── Uses more storage (raw + transformed)
└── Target system does heavy lifting
```

**Kafka's approach: Single Message Transformations (SMTs)**

```
Lightweight transformations in Connect:
├── Add/remove fields
├── Rename fields
├── Mask sensitive data
├── Change data types
├── Route to different topics
└── Filter messages

For complex transformations:
└── Use Kafka Streams
    ├── Joins across streams
    ├── Aggregations
    ├── Windowing
    └── Stateful processing
```

> **💡 Insight**
>
> Start with minimal transformation (ELT approach). Only add transformations that benefit all downstream consumers - like removing PII, standardizing timestamps, or adding lineage metadata.

### 3.6. Security

**In plain English:** Security ensures only authorized systems can read/write data, sensitive data is encrypted in transit, and you can audit who accessed what.

**Security considerations:**

**1. Access control**
```
Questions:
├── Who can read data in Kafka?
├── Who can write to which topics?
└── Who can modify connectors?

Kafka provides:
├── ACLs (Access Control Lists)
├── Authentication (SASL, mutual TLS)
└── Authorization (topic-level, group-level)
```

**2. Encryption**
```
Data in transit:
├── TLS encryption between clients and brokers
├── TLS between brokers
└── TLS for Connect workers

Data at rest:
└── Disk encryption (OS/storage level)
```

**3. Credential management**
```
Connect connectors need credentials for:
├── Source databases
├── Destination systems
├── Schema Registry
└── External APIs

Best practice:
├── DON'T store in config files
├── USE external secret management
    ├── HashiCorp Vault
    ├── AWS Secrets Manager
    ├── Azure Key Vault
    └── Kafka's pluggable secret providers
```

**4. Audit logging**
```
Track:
├── Who accessed which topics
├── When data was accessed
├── What operations were performed
└── Source of each record (lineage)
```

**5. PII compliance (GDPR, CCPA)**
```
Requirements:
├── Identify PII in data
├── Mask or encrypt PII
├── Delete data on request
└── Track data lineage

SMT for PII:
└── MaskField transformation
    └── Replace field values with null
```

### 3.7. Failure Handling

**In plain English:** Assume data will be messy and systems will fail. Plan for recovery rather than hoping for perfection.

**Failure scenarios:**

**1. Bad records**
```
Options:
├── Reject entire batch (stop pipeline)
├── Skip bad record (log and continue)
├── Route to dead letter queue (DLQ)
└── Alert and wait for human intervention

Connect configuration:
errors.tolerance = none | all
errors.deadletterqueue.topic.name = <topic>
```

**2. System failures**
```
Source system down:
└── Connect retries, eventually fails task
    └── Operator alerted, restarts when source available

Destination system down:
└── Connect retries, data backs up in Kafka
    └── Resumes when destination available

Kafka down:
└── Producers buffer locally (within limits)
    └── Resume when Kafka available
```

**3. Data corruption**
```
Unparseable data:
├── Serialization error
└── Schema mismatch

Solutions:
├── Validation before producing
├── Schema evolution support
└── DLQ for investigation
```

**Kafka's replay capability:**
```
Advantage:
├── Kafka retains data for days/weeks
├── Can replay from any point
└── Recover from processing errors

Example:
1. Bug in consumer corrupts data in database
2. Fix the bug
3. Reset consumer offset to before bug
4. Replay and reprocess correctly
```

> **💡 Insight**
>
> Kafka's retention is your safety net. Configure longer retention for critical topics so you can replay data when things go wrong. This is cheaper than building complex error recovery systems.

### 3.8. Coupling and Agility

**In plain English:** Tight coupling means systems depend on each other's internals. Loose coupling means systems interact through stable interfaces and can evolve independently.

**Anti-patterns that create coupling:**

**1. Ad-hoc pipelines**
```
Problem:
├── Logstash for logs → Elasticsearch
├── Flume for logs → HDFS
├── GoldenGate for Oracle → HDFS
├── Informatica for MySQL → Oracle
└── Each tool for each connection pair

Result:
├── N×M integration points
├── Each tool needs expertise
└── Adding new system requires new pipelines
```

**2. Lost metadata**
```
Problem:
├── Pipeline doesn't preserve schema
└── Source and destination must agree on format

Example:
MySQL adds column → App reading from HDFS breaks
└── No schema evolution support

Better:
└── Preserve schema in Kafka (Schema Registry)
    └── Safe, independent evolution
```

**3. Excessive transformation**
```
Problem:
Pipeline filters out "unnecessary" fields
└── Later, someone needs those fields
    └── Must rebuild pipeline and reprocess history

Better:
└── Keep most data, let consumers decide
    └── Add new consumers without changing pipeline
```

**Kafka Connect promotes loose coupling:**

```
Benefits:
├── Standard connectors for common systems
├── Schema evolution support (with Avro/Schema Registry)
├── Add new sources/destinations independently
└── Change Kafka storage format without touching connectors
```

---

## 4. Kafka Connect vs Producer/Consumer

**When to use Producer/Consumer (client APIs):**

```
Use when:
├── You control the application code
├── Application needs to send/receive data
├── Custom business logic required
└── Integration with application framework

Examples:
├── Web application logs events
├── Service publishes metrics
├── Microservice consumes orders
```

**When to use Kafka Connect:**

```
Use when:
├── Connecting external datastores
├── Don't control the source/destination code
├── Want standard, reusable solution
└── Don't want to manage offset tracking, retries, etc.

Examples:
├── MySQL → Kafka
├── Kafka → Elasticsearch
├── MongoDB → Kafka
└── Kafka → S3
```

**Why use Connect even when you could write client code:**

```
Connect provides out-of-the-box:
├── Configuration management (REST API)
├── Offset storage and management
├── Parallelization and scaling
├── Error handling and retries
├── Metrics and monitoring
├── Standard data type conversions
└── Exactly-once semantics (for many connectors)

Writing custom app requires:
├── Implementing all of above
├── Testing edge cases
├── Documenting for teammates
└── Maintaining forever
```

> **💡 Insight**
>
> The 80/20 rule: A simple app moving data from database to Kafka takes a day. Making it production-ready with proper error handling, monitoring, scaling, and reliability takes months. Connect gives you months of work for free.

---

## 5. Kafka Connect Deep Dive

### 5.1. Running Connect

**Starting Connect:**

```bash
# Start in distributed mode (production)
bin/connect-distributed.sh config/connect-distributed.properties &
```

**Key configurations:**

```properties
# Kafka cluster to connect to
bootstrap.servers=broker1:9092,broker2:9092,broker3:9092

# Connect cluster identity
group.id=connect-cluster-1

# Where to find connector plugins
plugin.path=/opt/connectors,/usr/local/connectors

# How to store data in Kafka
key.converter=org.apache.kafka.connect.json.JsonConverter
value.converter=io.confluent.connect.avro.AvroConverter
value.converter.schema.registry.url=http://localhost:8081

# REST API configuration
rest.host.name=localhost
rest.port=8083

# Internal topics (Connect uses Kafka to store state)
offset.storage.topic=connect-offsets
config.storage.topic=connect-configs
status.storage.topic=connect-status
```

**Installing connectors:**

```bash
# 1. Create plugin directory
mkdir -p /opt/connectors/jdbc
mkdir -p /opt/connectors/elasticsearch

# 2. Place connector JARs and dependencies
cp kafka-connect-jdbc-*.jar /opt/connectors/jdbc/
cp kafka-connect-elasticsearch-*.jar /opt/connectors/elasticsearch/
cp mysql-connector-java-*.jar /opt/connectors/jdbc/  # JDBC driver

# 3. Update plugin.path in config
plugin.path=/opt/connectors

# 4. Restart Connect workers
```

**Verifying Connect is running:**

```bash
# Check Connect API
curl http://localhost:8083/

# List available connector plugins
curl http://localhost:8083/connector-plugins
```

### 5.2. Connector Examples

**Example 1: File Source to File Sink**

```bash
# Create file source connector
echo '{
  "name": "file-source",
  "config": {
    "connector.class": "FileStreamSource",
    "file": "input.txt",
    "topic": "file-topic"
  }
}' | curl -X POST -d @- http://localhost:8083/connectors \
  --header "Content-Type: application/json"

# Create file sink connector
echo '{
  "name": "file-sink",
  "config": {
    "connector.class": "FileStreamSink",
    "file": "output.txt",
    "topics": "file-topic"
  }
}' | curl -X POST -d @- http://localhost:8083/connectors \
  --header "Content-Type: application/json"

# Verify connectors
curl http://localhost:8083/connectors
```

**Example 2: MySQL to Elasticsearch**

**Step 1: Set up MySQL**
```sql
CREATE DATABASE test;
USE test;
CREATE TABLE login (
    username VARCHAR(30),
    login_time DATETIME
);
INSERT INTO login VALUES ('alice', NOW());
INSERT INTO login VALUES ('bob', NOW());
```

**Step 2: Create JDBC source connector**
```bash
echo '{
  "name": "mysql-source",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:3306/test?user=root",
    "mode": "timestamp",
    "table.whitelist": "login",
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql."
  }
}' | curl -X POST -d @- http://localhost:8083/connectors \
  --header "Content-Type: application/json"
```

**Step 3: Verify data in Kafka**
```bash
kafka-console-consumer --bootstrap-server localhost:9092 \
  --topic mysql.login --from-beginning
```

**Step 4: Create Elasticsearch sink connector**
```bash
echo '{
  "name": "elastic-sink",
  "config": {
    "connector.class": "ElasticsearchSinkConnector",
    "connection.url": "http://localhost:9200",
    "topics": "mysql.login",
    "key.ignore": "true"
  }
}' | curl -X POST -d @- http://localhost:8083/connectors \
  --header "Content-Type: application/json"
```

**Step 5: Verify data in Elasticsearch**
```bash
curl http://localhost:9200/mysql.login/_search?pretty=true
```

> **💡 Insight**
>
> The JDBC connector uses timestamp columns or incrementing IDs to detect new rows. For production, use CDC (Change Data Capture) connectors like Debezium, which read database transaction logs for more accurate and efficient data capture.

### 5.3. Single Message Transformations

**In plain English:** SMTs are lightweight transformations applied to each message as it flows through Connect, without writing code.

**Common transformations:**

```
Built-in SMTs:
├── Cast - Change field data types
├── MaskField - Remove sensitive data (set to null)
├── Filter - Drop or keep messages matching conditions
├── Flatten - Nested structure → Flat structure
├── HeaderFrom - Move data to message headers
├── InsertHeader - Add static header
├── InsertField - Add metadata (offset, timestamp)
├── RegexRouter - Change destination topic
├── ReplaceField - Rename or remove fields
├── TimestampConverter - Change time format
└── TimestampRouter - Route based on timestamp
```

**Example: Add header to track message source**

```bash
echo '{
  "name": "mysql-source-with-headers",
  "config": {
    "connector.class": "JdbcSourceConnector",
    "connection.url": "jdbc:mysql://localhost:3306/test?user=root",
    "mode": "timestamp",
    "table.whitelist": "login",
    "timestamp.column.name": "login_time",
    "topic.prefix": "mysql.",

    # Add transformation
    "transforms": "InsertHeader",
    "transforms.InsertHeader.type": "org.apache.kafka.connect.transforms.InsertHeader",
    "transforms.InsertHeader.header": "source",
    "transforms.InsertHeader.value.literal": "mysql-production"
  }
}' | curl -X POST -d @- http://localhost:8083/connectors \
  --header "Content-Type: application/json"
```

**Example: Mask PII fields**

```bash
"transforms": "maskPII",
"transforms.maskPII.type": "org.apache.kafka.connect.transforms.MaskField$Value",
"transforms.maskPII.fields": "ssn,credit_card,email"
```

**Example: Route to different topics based on field value**

```bash
"transforms": "route",
"transforms.route.type": "org.apache.kafka.connect.transforms.RegexRouter",
"transforms.route.regex": ".*",
"transforms.route.replacement": "$0-${topic.type}"
```

**Chain multiple transformations:**

```bash
"transforms": "mask,addHeaders,flatten",
"transforms.mask.type": "MaskField$Value",
"transforms.mask.fields": "password",
"transforms.addHeaders.type": "InsertHeader",
"transforms.addHeaders.header": "pipeline",
"transforms.addHeaders.value.literal": "prod",
"transforms.flatten.type": "Flatten$Value"
```

> **💡 Insight**
>
> SMTs are powerful but limited to single-record operations. For joins, aggregations, or stateful transformations, use Kafka Streams. Keep the pipeline simple (ELT approach) and do complex transformations downstream.

### 5.4. How Connect Works

**Three main components:**

**1. Connectors**
```
Responsibilities:
├── Determine how many tasks needed
├── Split work among tasks
├── Generate task configurations
└── Manage task lifecycle

Example - JDBC Source:
├── Discovers tables in database
├── Creates one task per table (up to tasks.max)
├── Gives each task a list of tables to copy
└── Tasks run on any available worker
```

**2. Tasks**
```
Responsibilities:
├── Actually move the data
├── Source tasks: Read from external system → Kafka
└── Sink tasks: Read from Kafka → Write to external system

Source task flow:
1. poll() - Read from source
2. Return list of records
3. Worker sends to Kafka
4. Worker commits offsets

Sink task flow:
1. Worker polls Kafka
2. Gives records to task
3. put() - Write to destination
4. Worker commits offsets if successful
```

**3. Workers**
```
Responsibilities:
├── REST API for managing connectors
├── Configuration management (stored in Kafka)
├── Offset management (stored in Kafka)
├── Reliability and error handling
├── Distributing connectors and tasks
└── Rebalancing on failures

Visual:
Worker 1:                    Worker 2:
├── Connector A (coordinator)├── Task A1
├── Task B2                  └── Task B3
└── Task C1

Worker 3:
├── Connector B (coordinator)
├── Connector C (coordinator)
└── Task A2

If Worker 1 fails:
└── Workers 2 and 3 split its tasks
```

**Data flow with converters:**

```
Source System → Source Connector → Data API objects
                                         ↓
                                    Converter
                                         ↓
                                    Kafka (Avro/JSON/etc)
                                         ↓
                                    Converter
                                         ↓
Sink Connector → Data API objects → Sink System
```

**Offset management:**

```
Source connector:
├── Returns records with source partition + offset
│   Example: {file: "log.txt", line: 42}
├── Worker sends to Kafka
└── Worker stores offset in __connect-offsets topic

Sink connector:
├── Worker reads from Kafka (has topic + partition + offset)
├── Gives records to sink task
├── Task writes to destination
└── Worker commits Kafka offsets

Benefit: Automatic, reliable offset tracking
```

> **💡 Insight**
>
> Workers handle all the hard distributed systems problems - configuration management, offset tracking, failure recovery, rebalancing. Connector developers just implement "read from system" or "write to system" logic. This separation is why Connect is so powerful.

---

## 6. Alternatives to Kafka Connect

**When other tools make sense:**

**1. Hadoop-centric architecture**
```
Tool: Apache Flume
Use when:
├── HDFS is primary data lake
├── Most processing in Hadoop ecosystem
└── Kafka is just one input among many
```

**2. Elasticsearch-centric architecture**
```
Tools: Logstash, Fluentd
Use when:
├── Elasticsearch is primary destination
├── Need complex log parsing
└── Kafka is one of many sources
```

**3. GUI-based ETL**
```
Tools: Informatica, Talend, Pentaho, Apache NiFi, StreamSets
Use when:
├── Organization standardized on GUI-based ETL
├── Non-technical users build pipelines
├── Complex workflow orchestration needed

Drawback:
└── Often heavier weight than needed for simple Kafka integration
```

**4. Stream processing frameworks**
```
Tools: Kafka Streams, Flink, Spark Streaming
Use when:
├── Need complex transformations (joins, aggregations)
├── Already using framework for processing
└── Can write results directly to destination

Trade-off:
├── ✓ Combines processing and integration
└── ✗ Harder to troubleshoot data flow issues
```

**When Kafka Connect is best:**

```
Choose Connect when:
├── Kafka is central to architecture
├── Need reliable, scalable data integration
├── Connecting multiple sources and destinations
├── Want standard, tested connectors
└── Need operational simplicity
```

> **💡 Insight**
>
> Kafka as a platform can handle data integration (Connect), application integration (producers/consumers), and stream processing (Streams). This unified platform reduces the number of technologies teams must learn and maintain.

---

## 7. Summary

**What we learned:**

**1. Data pipeline considerations**
```
Design for:
├── Timeliness (real-time to batch)
├── Reliability (at-least-once to exactly-once)
├── Throughput (handle spikes, scale independently)
├── Data formats (translate between systems)
├── Transformations (ETL vs ELT)
├── Security (encryption, access control, PII)
├── Failure handling (retries, DLQs, replay)
└── Coupling (loose vs tight)
```

**2. Kafka's pipeline advantages**
```
Kafka provides:
├── Scalable, reliable buffer
├── Decouples producers from consumers
├── Supports multiple consumption patterns
├── Handles varying throughput
├── Preserves data for replay
└── Schema evolution support
```

**3. Kafka Connect benefits**
```
Connect provides:
├── Standard connectors for common systems
├── Automatic offset management
├── Configuration via REST API
├── Distributed execution
├── Fault tolerance and scaling
├── Exactly-once support
└── Standard error handling
```

**4. Architecture patterns**

**Pattern 1: Hub and spoke**
```
Many sources → Kafka → Many destinations
├── Decouple source and destination changes
├── Add new systems without affecting existing
└── Central platform for data integration
```

**Pattern 2: CDC to data warehouse**
```
Databases → CDC connectors → Kafka → Warehouse sink
├── Near real-time data warehouse
├── Preserve transaction order
└── Schema evolution support
```

**Pattern 3: Event-driven microservices**
```
Service A → Kafka → Service B
                  → Service C
├── Publish events once
├── Multiple consumers process independently
└── Loose coupling between services
```

**Key recommendations:**

**Start with ELT, not ETL:**
```
Preserve raw data in Kafka:
├── Maximum flexibility for consumers
├── Can always add new transformations
├── Easier to troubleshoot
└── Only add transformations that benefit everyone
```

**Use schema registry:**
```
Benefits:
├── Schema evolution support
├── Compatibility checking
├── Self-documenting data
└── Type safety
```

**Test failure scenarios:**
```
Validate:
├── Source system down
├── Destination system down
├── Network partitions
├── Bad data
└── Replay from any offset
```

**Monitor the entire pipeline:**
```
Track:
├── Records per second (source and destination)
├── Consumer lag
├── Error rates
├── End-to-end latency
└── Reconcile counts match
```

**Key takeaway:** Data integration is reliability-critical infrastructure. Kafka Connect provides production-grade reliability, scalability, and operational simplicity. While you can write custom code to move data, Connect's built-in features for offset management, error handling, and distributed execution are worth far more than the effort to write connectors.

**Pro tip:** Start with existing connectors from Confluent Hub or community. Only write custom connectors if your data source/destination isn't already supported. When you do write custom connectors, contribute them back to the community - everyone benefits from reusable, tested integration components.

---

**Previous:** [Chapter 8: Exactly-Once Semantics](./chapter8.md) | **Next:** [Chapter 10: Cross-Cluster Data Mirroring →](./chapter10.md)
