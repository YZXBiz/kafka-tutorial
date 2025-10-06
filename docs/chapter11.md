# 11. Securing Kafka

> **In plain English:** Securing Kafka is like protecting a postal system—you need to verify who's sending letters (authentication), check what they're allowed to send (authorization), seal envelopes so others can't read them (encryption), and keep records of all mailings (auditing).
>
> **In technical terms:** Kafka security involves implementing authentication, authorization, encryption, auditing, and quotas to ensure confidentiality, integrity, and availability of streaming data.
>
> **Why it matters:** From website analytics to payment processing to patient records, Kafka handles data with vastly different security requirements. One breach can cost millions in damages, regulatory fines, and lost trust.

---

## Table of Contents

1. [Introduction](#1-introduction)
2. [Security Fundamentals](#2-security-fundamentals)
   - 2.1. [The Five Pillars of Security](#21-the-five-pillars-of-security)
   - 2.2. [Understanding Data Flow](#22-understanding-data-flow)
3. [Security Protocols](#3-security-protocols)
   - 3.1. [Protocol Overview](#31-protocol-overview)
   - 3.2. [Choosing the Right Protocol](#32-choosing-the-right-protocol)
4. [Authentication](#4-authentication)
   - 4.1. [SSL/TLS Authentication](#41-ssltls-authentication)
   - 4.2. [SASL Authentication](#42-sasl-authentication)
   - 4.3. [Delegation Tokens](#43-delegation-tokens)
   - 4.4. [Reauthentication](#44-reauthentication)
5. [Encryption](#5-encryption)
   - 5.1. [Transport Encryption](#51-transport-encryption)
   - 5.2. [End-to-End Encryption](#52-end-to-end-encryption)
6. [Authorization](#6-authorization)
   - 6.1. [ACL-Based Authorization](#61-acl-based-authorization)
   - 6.2. [Custom Authorization](#62-custom-authorization)
7. [Auditing and Monitoring](#7-auditing-and-monitoring)
8. [Securing ZooKeeper](#8-securing-zookeeper)
9. [Platform Security](#9-platform-security)
10. [Summary](#10-summary)

---

## 1. Introduction

Security isn't a feature you add at the end—it's a foundation you build from the start. Like a chain, your system is only as strong as its weakest link.

**Key Principle:** Security must be addressed system-wide, not component by component. Kafka's customizable security features let you integrate with existing infrastructure to build a consistent security model across your entire system.

---

## 2. Security Fundamentals

### 2.1. The Five Pillars of Security

Kafka uses five complementary approaches to protect your data:

**1. Authentication: Who Are You?**
```
Process: Establishes your identity
Question: Are you really Alice, or an imposter?
Methods: Passwords, certificates, Kerberos tickets
```

**2. Authorization: What Can You Do?**
```
Process: Determines your permissions
Question: Can Alice write to the customerOrders topic?
Methods: Access Control Lists (ACLs), roles
```

**3. Encryption: Protect From Eavesdropping**
```
Process: Scrambles data so others can't read it
Types:   In transit (network), at rest (disk)
Methods: TLS/SSL, disk encryption
```

**4. Auditing: What Did You Do?**
```
Process: Tracks all operations
Purpose: Detect suspicious activity, meet compliance
Output:  Logs of who did what, when
```

**5. Quotas: Fair Resource Usage**
```
Process: Limits resource consumption
Purpose: Prevent denial-of-service attacks
Metrics: Bytes/second, connections/second
```

> **💡 Insight**
>
> These five pillars work together. Authentication without authorization is like checking IDs at the door but letting everyone do anything. Encryption without authentication is like whispering to someone you haven't verified. You need all five for complete security.

### 2.2. Understanding Data Flow

Let's follow a message through Kafka to understand where security applies:

```
Data Flow Example:
─────────────────────────────────────────────────────
1. Alice → Producer → Broker (Leader)
   Security: Authenticate Alice, authorize write, encrypt connection

2. Broker Leader → Disk
   Security: Encrypt disk (optional)

3. Broker Leader → Broker Follower
   Security: Authenticate broker, authorize replication, encrypt

4. Broker → ZooKeeper
   Security: Authenticate broker, authorize metadata update

5. Broker → Bob's Consumer
   Security: Authenticate Bob, authorize read, encrypt connection

6. Internal App → Consumer
   Security: Authenticate app, authorize read, log access
```

**Security Requirements at Each Step:**

**Step 1: Client to Broker**
- ✓ Authenticate Alice (who is sending?)
- ✓ Authenticate broker (is this the real broker?)
- ✓ Encrypt connection (prevent eavesdropping)
- ✓ Authorize write (can Alice write here?)

**Step 2: Broker to Disk**
- ✓ Encrypt disk (optional, for physical security)
- ✓ Protect files with OS permissions

**Step 3: Broker to Broker**
- ✓ Authenticate follower broker
- ✓ Encrypt replication traffic
- ✓ Authorize replica fetch

**Step 4: Broker to ZooKeeper**
- ✓ Authenticate broker
- ✓ Encrypt metadata updates
- ✓ Authorize state changes

**Step 5: Broker to Consumer**
- ✓ Authenticate Bob
- ✓ Authorize read
- ✓ Encrypt connection
- ✓ Log access

---

## 3. Security Protocols

### 3.1. Protocol Overview

Kafka supports four security protocols, combining transport layers with authentication:

**The Four Protocols:**

```
Transport Layer:    PLAINTEXT    |    SSL
                        │              │
                        ▼              ▼
Authentication:    None/SASL      SSL/SASL
                        │              │
                        ▼              ▼
Protocols:        PLAINTEXT      SSL
                  SASL_PLAINTEXT SASL_SSL
```

**1. PLAINTEXT**
```
Transport:      Unencrypted
Authentication: None
Use case:       Private networks, non-sensitive data
Security level: ⚠️ LOW - No protection
```

**2. SSL**
```
Transport:      Encrypted (TLS)
Authentication: SSL certificates (optional client auth)
Use case:       Public networks, sensitive data
Security level: ✓ HIGH - Full protection
```

**3. SASL_PLAINTEXT**
```
Transport:      Unencrypted
Authentication: SASL (Kerberos, passwords, tokens)
Use case:       Private networks with authentication
Security level: ⚠️ MEDIUM - Authenticated but not encrypted
```

**4. SASL_SSL**
```
Transport:      Encrypted (TLS)
Authentication: SASL + SSL certificates
Use case:       Public networks, maximum security
Security level: ✓ VERY HIGH - Authentication + encryption
```

### 3.2. Choosing the Right Protocol

**Decision Tree:**

```
Is your network private and physically secure?
├─ No → Use SSL or SASL_SSL
│       Is the data sensitive?
│       ├─ Yes → SASL_SSL (maximum security)
│       └─ No  → SSL (good security)
│
└─ Yes → Consider PLAINTEXT or SASL_PLAINTEXT
          Do you need authentication?
          ├─ Yes → SASL_PLAINTEXT
          └─ No  → PLAINTEXT (testing/dev only)
```

**Configuration Example:**

```properties
# Define multiple listeners with different security
listeners=EXTERNAL://:9092,INTERNAL://10.0.0.2:9093,BROKER://10.0.0.2:9094

# Map each listener to a security protocol
listener.security.protocol.map=\
  EXTERNAL:SASL_SSL,\      # Public internet
  INTERNAL:SSL,\           # Internal apps
  BROKER:SSL               # Inter-broker

# Choose inter-broker listener
inter.broker.listener.name=BROKER
```

**Client Configuration:**

```properties
# Connect to external listener
security.protocol=SASL_SSL
bootstrap.servers=broker1.example.com:9092,broker2.example.com:9092
```

> **💡 Insight**
>
> Multiple listeners let you tailor security to each use case. External clients get maximum security (SASL_SSL), while internal systems can use lighter-weight SSL, and brokers can optimize inter-broker communication.

---

## 4. Authentication

Authentication answers the question: **"Who are you?"**

### 4.1. SSL/TLS Authentication

**How It Works:**

```
Client Authentication Flow:
──────────────────────────────────────────
1. Client connects to broker
2. Broker sends its certificate
3. Client verifies broker certificate
4. If client auth enabled:
   - Client sends its certificate
   - Broker verifies client certificate
5. Session established
```

**In plain English:** SSL authentication uses digital certificates like government-issued IDs. The certificate proves you are who you claim to be because it's been signed by a trusted authority (Certificate Authority).

**Setting Up SSL:**

**Step 1: Create Certificates**

```bash
# Generate CA (Certificate Authority)
keytool -genkeypair -keyalg RSA -keysize 2048 \
  -keystore server.ca.p12 -storetype PKCS12 \
  -storepass ca-password -keypass ca-password \
  -alias ca -dname "CN=BrokerCA" \
  -ext bc=ca:true -validity 365

# Export CA certificate
keytool -export -file server.ca.crt \
  -keystore server.ca.p12 -storetype PKCS12 \
  -storepass ca-password -alias ca -rfc
```

**Step 2: Create Broker Certificate**

```bash
# Generate broker private key
keytool -genkey -keyalg RSA -keysize 2048 \
  -keystore server.ks.p12 -storetype PKCS12 \
  -storepass ks-password -keypass ks-password \
  -alias server -dname "CN=Kafka,O=Company,C=US"

# Create signing request
keytool -certreq -file server.csr \
  -keystore server.ks.p12 -storetype PKCS12 \
  -storepass ks-password -alias server

# Sign with CA
keytool -gencert -infile server.csr -outfile server.crt \
  -keystore server.ca.p12 -storetype PKCS12 \
  -storepass ca-password -alias ca \
  -ext SAN=DNS:broker1.example.com -validity 365

# Import signed certificate
cat server.crt server.ca.crt > serverchain.crt
keytool -importcert -file serverchain.crt \
  -keystore server.ks.p12 -storepass ks-password \
  -alias server -storetype PKCS12 -noprompt
```

**Step 3: Configure Broker**

```properties
# SSL keystore (broker's identity)
ssl.keystore.location=/path/to/server.ks.p12
ssl.keystore.password=ks-password
ssl.key.password=ks-password
ssl.keystore.type=PKCS12

# SSL truststore (who to trust)
ssl.truststore.location=/path/to/server.ts.p12
ssl.truststore.password=ts-password
ssl.truststore.type=PKCS12

# Require client authentication
ssl.client.auth=required
```

**Step 4: Configure Client**

```properties
# Trust the broker's CA
ssl.truststore.location=/path/to/client.ts.p12
ssl.truststore.password=ts-password
ssl.truststore.type=PKCS12

# If client auth required
ssl.keystore.location=/path/to/client.ks.p12
ssl.keystore.password=ks-password
ssl.key.password=ks-password
ssl.keystore.type=PKCS12
```

**Visual Flow:**

```
Certificate Chain:
──────────────────────────────────────────
Root CA Certificate (self-signed)
     │
     │ signs
     ▼
Broker Certificate (CN=broker1.example.com)
     │
     │ sent to client
     ▼
Client verifies:
  1. Certificate signed by trusted CA?
  2. Hostname matches?
  3. Not expired?
  4. Not revoked?
```

> **💡 Insight**
>
> Hostname verification is critical! It prevents man-in-the-middle attacks where an attacker intercepts your connection and presents their own valid certificate. Always include the broker's hostname in the certificate's SAN field.

### 4.2. SASL Authentication

SASL (Simple Authentication and Security Layer) provides a framework for multiple authentication mechanisms.

**The Four SASL Mechanisms:**

**1. SASL/GSSAPI (Kerberos)**
```
Best for:  Enterprise environments with Active Directory
Security:  Very strong (mutual authentication)
Complexity: High (requires Kerberos infrastructure)
Use case:  Large organizations, strict security requirements
```

**2. SASL/PLAIN**
```
Best for:  Simple username/password (with custom validation)
Security:  Weak (sends passwords) - MUST use with SSL
Complexity: Low
Use case:  Small deployments, custom auth systems
```

**3. SASL/SCRAM**
```
Best for:  Username/password without external dependencies
Security:  Strong (salted hashed passwords)
Complexity: Medium
Use case:  Most production deployments
```

**4. SASL/OAUTHBEARER**
```
Best for:  OAuth 2.0 token-based authentication
Security:  Strong (short-lived tokens)
Complexity: Medium-High
Use case:  Microservices, modern auth systems
```

**Choosing a SASL Mechanism:**

```
Do you have Kerberos infrastructure?
├─ Yes → Use GSSAPI
│        ✓ Best security
│        ✓ Enterprise integration
│        ⚠ Requires KDC maintenance
│
└─ No → Do you have OAuth server?
         ├─ Yes → Use OAUTHBEARER
         │        ✓ Modern, token-based
         │        ✓ Short-lived credentials
         │
         └─ No → Use SCRAM
                  ✓ Built into Kafka
                  ✓ No external dependencies
                  ✓ Good security

⚠️ PLAIN: Only with custom callbacks and SSL!
```

**SCRAM Configuration Example:**

**Step 1: Create Users**

```bash
# Create user with SCRAM-SHA-512
bin/kafka-configs.sh --zookeeper localhost:2181 \
  --alter --add-config \
  'SCRAM-SHA-512=[iterations=8192,password=alice-secret]' \
  --entity-type users --entity-name alice
```

**Step 2: Configure Broker**

```properties
# Enable SCRAM
sasl.enabled.mechanisms=SCRAM-SHA-512
sasl.mechanism.inter.broker.protocol=SCRAM-SHA-512

# Broker credentials (for inter-broker)
listener.name.external.scram-sha-512.sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="kafka" password="kafka-password";
```

**Step 3: Configure Client**

```properties
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  username="alice" password="alice-secret";
```

**How SCRAM Works:**

```
SCRAM Authentication Flow:
──────────────────────────────────────────
1. Client sends username
2. Server sends salt + iteration count
3. Client computes salted hash
4. Client sends proof
5. Server verifies proof
6. Server sends server signature
7. Client verifies server signature
8. ✓ Mutual authentication complete

Benefits:
- Password never sent over wire
- Salted hash prevents rainbow tables
- High iteration count slows brute-force
- Mutual authentication (both verify each other)
```

### 4.3. Delegation Tokens

**The Problem:**
```
Distributing SSL certificates or Kerberos keytabs
to hundreds of workers is complex and risky
```

**The Solution:**
```
Delegation tokens = lightweight shared secrets
- Created by authenticated client
- Distributed to workers
- Workers auth with token instead of full credentials
```

**Use Case Example:**

```
Kafka Connect Cluster:
──────────────────────────────────────────
Connect Leader (authenticated with Kerberos)
     │
     │ Creates delegation token
     ▼
Distributes token to workers
     │
     ├──→ Worker 1 (auths with token)
     ├──→ Worker 2 (auths with token)
     └──→ Worker 3 (auths with token)

Benefits:
- No need to distribute keytabs to all workers
- Reduces load on Kerberos KDC
- Easier to revoke (delete token)
```

**Creating Delegation Tokens:**

```bash
# Create token for Alice
bin/kafka-delegation-tokens.sh \
  --bootstrap-server localhost:9092 \
  --command-config alice.props \
  --create \
  --max-life-time-period -1 \
  --renewer-principal User:bob

# Output:
# Token ID: MTIz
# HMAC: c2VjcmV0
```

**Using Delegation Token:**

```properties
sasl.mechanism=SCRAM-SHA-512
sasl.jaas.config=\
  org.apache.kafka.common.security.scram.ScramLoginModule required \
  tokenauth="true" \
  username="MTIz" \
  password="c2VjcmV0";
```

### 4.4. Reauthentication

**The Problem:**

```
Traditional Authentication:
──────────────────────────────────────────
1. Client connects → Authenticated ✓
2. Connection stays open for days/weeks
3. User's password changed
4. User leaves company
5. Connection still active! ⚠️
```

**The Solution:**

```
Reauthentication:
──────────────────────────────────────────
1. Client connects → Authenticated ✓
2. Every N minutes → Reauthenticate
3. If auth fails → Close connection
4. Limits exposure of compromised credentials
```

**Configuration:**

```properties
# Broker config
connections.max.reauth.ms=3600000  # 1 hour

# Forces reauthentication every hour
# Applies to all SASL connections
```

**Benefits:**

```
Use Case                          Protection
─────────────────────────────────────────────────────
Password changed                  Old password expires in 1 hour
User leaves company               Access revoked within 1 hour
Kerberos ticket expires           New ticket acquired automatically
OAuth token expires               New token required
Compromised credentials           Limited time window for damage
```

---

## 5. Encryption

### 5.1. Transport Encryption

**When to Use:**
- Data crosses networks you don't control
- Data might be intercepted (public internet, untrusted LANs)
- Regulatory requirements (HIPAA, PCI-DSS, GDPR)

**How It Works:**

```
SSL/TLS Handshake:
──────────────────────────────────────────
1. Client: "Hello, I support these ciphers"
2. Server: "Let's use AES-256, here's my certificate"
3. Client: Verifies certificate, generates session key
4. Client: Sends session key (encrypted with server's public key)
5. Server: Decrypts session key
6. Both: All future data encrypted with session key

Result: Encrypted tunnel
- Prevents eavesdropping
- Detects tampering
- Fast (symmetric encryption for data)
```

**Performance Impact:**

```
SSL Overhead:
──────────────────────────────────────────
CPU Usage:        +20-30%
Throughput:       -10-15%
Latency:          +5-10ms (handshake)

Mitigation:
- Use modern CPUs with AES-NI
- Keep connections long-lived
- Use strong ciphers (AES-256)
- Consider hardware accelerators for very high throughput
```

### 5.2. End-to-End Encryption

**When to Use:**

```
Scenario: You don't trust the platform
─────────────────────────────────────────────
Problem:  Cloud provider admins can access:
          - Broker memory (heap dumps)
          - Disk files (log segments)
          - Network traffic (if SSL disabled internally)

Solution: Encrypt messages before sending to Kafka
          Decrypt messages after receiving from Kafka
          Broker never sees plaintext
```

**Architecture:**

```
End-to-End Encryption Flow:
──────────────────────────────────────────
Producer                 Broker                 Consumer
────────                 ──────                 ────────
Plaintext                                       Plaintext
   │                                                ▲
   │ Encrypt (AES-256)                             │ Decrypt
   ▼                                                │
Ciphertext ──────────→ Stores ──────────→ Ciphertext
                       Ciphertext
                       (never sees plaintext!)
   │                                                ▲
   │                                                │
   └─── Shared Key from KMS ────────────────────────┘
```

**Implementation Pattern:**

```java
// Producer: Encrypt in serializer
public class EncryptingSerializer implements Serializer<MyData> {
    private KmsClient kms;
    private Cipher cipher;

    @Override
    public byte[] serialize(String topic, MyData data) {
        // 1. Serialize to bytes
        byte[] plaintext = jsonSerializer.serialize(data);

        // 2. Get encryption key from KMS
        SecretKey key = kms.getKey("my-encryption-key");

        // 3. Encrypt
        cipher.init(Cipher.ENCRYPT_MODE, key);
        byte[] ciphertext = cipher.doFinal(plaintext);

        // 4. Store IV and encrypted data
        return combine(cipher.getIV(), ciphertext);
    }
}

// Consumer: Decrypt in deserializer
public class DecryptingDeserializer implements Deserializer<MyData> {
    private KmsClient kms;
    private Cipher cipher;

    @Override
    public MyData deserialize(String topic, byte[] data) {
        // 1. Extract IV and ciphertext
        byte[] iv = extractIV(data);
        byte[] ciphertext = extractCiphertext(data);

        // 2. Get decryption key from KMS
        SecretKey key = kms.getKey("my-encryption-key");

        // 3. Decrypt
        cipher.init(Cipher.DECRYPT_MODE, key, new IvParameterSpec(iv));
        byte[] plaintext = cipher.doFinal(ciphertext);

        // 4. Deserialize
        return jsonSerializer.deserialize(plaintext);
    }
}
```

**Key Management:**

```
Encryption Key Lifecycle:
──────────────────────────────────────────
1. Generate key in KMS
2. Producers/consumers fetch key
3. Rotate key periodically (e.g., monthly)
4. Keep old keys for retention period
5. Re-encrypt old data (optional, for compacted topics)
```

> **💡 Insight**
>
> Compression after encryption is useless—encrypted data looks random and won't compress. Compress BEFORE encrypting. Better yet, disable Kafka's compression since it won't help encrypted messages.

---

## 6. Authorization

Authorization answers: **"What are you allowed to do?"**

### 6.1. ACL-Based Authorization

**How ACLs Work:**

```
Access Control Lists:
──────────────────────────────────────────
Each ACL specifies:
- WHO:       User:alice, Group:engineers
- CAN DO:    Read, Write, Create, Delete
- WHAT:      Topic:orders, Group:my-app
- WHERE:     From IP 192.168.1.100
- ALLOW/DENY: Allow (or Deny with higher priority)
```

**ACL Structure:**

```
Example ACL:
──────────────────────────────────────────
Resource:    Topic "customer-orders"
Pattern:     Literal (exact match)
Principal:   User:alice
Host:        192.168.1.100
Operation:   Write
Permission:  Allow

Meaning: Alice from 192.168.1.100 can write to "customer-orders"
```

**Common ACL Patterns:**

**1. Producer ACLs:**

```bash
# Allow Alice to produce to customer-orders
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --add \
  --allow-principal User:alice \
  --producer \
  --topic customer-orders

# Grants:
# - Topic:Write on customer-orders
# - Topic:Describe on customer-orders
# - Cluster:IdempotentWrite (if using idempotent producer)
```

**2. Consumer ACLs:**

```bash
# Allow Bob to consume from customer-orders
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --add \
  --allow-principal User:bob \
  --consumer \
  --topic customer-orders \
  --group my-consumer-group

# Grants:
# - Topic:Read on customer-orders
# - Topic:Describe on customer-orders
# - Group:Read on my-consumer-group
```

**3. Prefix ACLs:**

```bash
# Allow all topics starting with "metrics-"
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --add \
  --allow-principal User:monitoring \
  --operation Read \
  --resource-pattern-type prefixed \
  --topic metrics-

# Grants access to:
# - metrics-app1
# - metrics-app2
# - metrics-database
# - etc.
```

**4. Wildcard ACLs:**

```bash
# Grant admin full access to everything
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --add \
  --allow-principal User:admin \
  --operation All \
  --topic '*' \
  --cluster \
  --group '*'
```

**Authorization Decision Process:**

```
Request: User:alice wants to Write to Topic:orders
──────────────────────────────────────────────────────

Step 1: Check for DENY ACLs
  ├─ Is there a DENY ACL matching this request?
  │  ├─ YES → Reject immediately (DENY wins)
  │  └─ NO  → Continue to Step 2

Step 2: Check for ALLOW ACLs
  ├─ Is there an ALLOW ACL matching this request?
  │  ├─ YES → Grant access ✓
  │  └─ NO  → Continue to Step 3

Step 3: Default Policy
  └─ Check allow.everyone.if.no.acl.found
     ├─ TRUE  → Grant access (insecure!)
     └─ FALSE → Reject (secure default)
```

**ACL Listing:**

```bash
# List all ACLs
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --list

# List ACLs for specific user
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --list \
  --principal User:alice

# List ACLs for specific topic
bin/kafka-acls.sh --bootstrap-server localhost:9092 \
  --command-config admin.props \
  --list \
  --topic customer-orders
```

### 6.2. Custom Authorization

**Use Cases for Custom Authorizers:**

```
1. Role-Based Access Control (RBAC)
   ├─ User:alice has Role:engineer
   └─ Role:engineer can read metrics-* topics

2. Attribute-Based Access Control (ABAC)
   ├─ If user.department == "sales"
   └─ Then allow read customer-* topics

3. Integration with External Systems
   ├─ Query LDAP/Active Directory for groups
   └─ Check database for dynamic permissions

4. Custom Business Logic
   ├─ Allow writes only during business hours
   └─ Rate limit per user or department
```

**Simple Custom Authorizer Example:**

```java
public class TimeBasedAuthorizer extends AclAuthorizer {

    @Override
    public List<AuthorizationResult> authorize(
            AuthorizableRequestContext context,
            List<Action> actions) {

        // Business hours only (9 AM - 5 PM)
        int hour = LocalTime.now().getHour();
        boolean businessHours = hour >= 9 && hour < 17;

        if (!businessHours && isWriteOperation(context)) {
            // Block writes outside business hours
            return Collections.nCopies(actions.size(), DENIED);
        }

        // Delegate to standard ACL check
        return super.authorize(context, actions);
    }

    private boolean isWriteOperation(AuthorizableRequestContext context) {
        return context.requestType() == ApiKeys.PRODUCE.id ||
               context.requestType() == ApiKeys.CREATE_TOPICS.id;
    }
}
```

---

## 7. Auditing and Monitoring

**What to Log:**

```
Security Events to Track:
──────────────────────────────────────────
✓ Authentication failures
✓ Authorization denials
✓ Successful authentications
✓ All administrative operations
✓ ACL changes
✓ Configuration changes
✓ User additions/deletions
```

**Log Configuration:**

```properties
# log4j.properties

# Authorization logs (DENY at INFO, ALLOW at DEBUG)
log4j.logger.kafka.authorizer.logger=DEBUG, authorizerAppender
log4j.additivity.kafka.authorizer.logger=false

# Request logs (all requests at DEBUG)
log4j.logger.kafka.request.logger=DEBUG, requestAppender
log4j.additivity.kafka.request.logger=false
```

**Sample Log Entries:**

```
# Denied access
INFO Principal=User:alice is Denied Operation=Write \
  from host=10.0.0.5 on resource=Topic:LITERAL:secret-topic \
  for request=Produce (kafka.authorizer.logger)

# Granted access
DEBUG Principal=User:bob is Allowed Operation=Read \
  from host=10.0.0.10 on resource=Topic:LITERAL:orders \
  for request=Fetch (kafka.authorizer.logger)

# Request details
DEBUG Completed request:RequestHeader(apiKey=PRODUCE,...) \
  from connection 10.0.0.5:9092;principal:User:alice \
  (kafka.request.logger)
```

**Log Analysis:**

```
Suspicious Patterns to Watch:
──────────────────────────────────────────
1. Multiple auth failures from same user
   → Possible brute-force attack

2. Access denied to resources
   → Misconfigured app or unauthorized access attempt

3. Access from unusual IP addresses
   → Possible credential compromise

4. Access patterns change suddenly
   → Possible account takeover

5. ACL modifications
   → Ensure authorized by admin
```

---

## 8. Securing ZooKeeper

**Why Secure ZooKeeper:**

```
ZooKeeper stores critical metadata:
──────────────────────────────────────────
- Broker information
- Topic configurations
- ACLs
- SCRAM credentials
- Controller information
- Partition leadership

If ZooKeeper is compromised:
⚠️ Entire Kafka cluster can be controlled
⚠️ All security can be bypassed
```

**ZooKeeper Security Options:**

**1. SASL Authentication:**

```properties
# ZooKeeper config
authProvider.sasl=org.apache.zookeeper.server.auth.SASLAuthenticationProvider
kerberos.removeHostFromPrincipal=true
kerberos.removeRealmFromPrincipal=true
```

**2. SSL Encryption:**

```properties
# ZooKeeper config
secureClientPort=2181
serverCnxnFactory=org.apache.zookeeper.server.NettyServerCnxnFactory
ssl.keyStore.location=/path/to/zk.ks.p12
ssl.trustStore.location=/path/to/zk.ts.p12
```

**3. ACLs:**

```properties
# Kafka broker config
zookeeper.set.acl=true

# Results:
# - Metadata readable by all
# - Metadata writable only by brokers
# - Sensitive data (credentials) not world-readable
```

---

## 9. Platform Security

Security extends beyond Kafka itself.

**System-Level Security:**

```
Security Layers:
──────────────────────────────────────────
1. Network
   ├─ Firewalls (limit access to Kafka ports)
   ├─ Network segmentation (isolate Kafka network)
   └─ VPNs (for remote access)

2. Operating System
   ├─ File permissions on config files
   ├─ File permissions on log directories
   ├─ File permissions on key stores
   └─ SELinux/AppArmor policies

3. Storage
   ├─ Disk encryption (LUKS, BitLocker)
   ├─ Volume encryption (dm-crypt)
   └─ Encrypted backups

4. Credentials
   ├─ No cleartext passwords in configs
   ├─ Use encrypted configs or external stores
   └─ Rotate regularly
```

**Password Protection:**

```
Problem: Passwords in config files
──────────────────────────────────────────
Even with file permissions, this is risky:
- Backups might not be protected
- Log files might show configs
- Admins can read files

Solution: Externalize passwords
──────────────────────────────────────────
```

**Using Config Providers:**

```properties
# Original (insecure)
ssl.keystore.password=my-secret-password

# Externalized (secure)
ssl.keystore.password=${file:/secure/passwords.properties:keystore.password}

# Provider configuration
config.providers=file
config.providers.file.class=org.apache.kafka.common.config.provider.FileConfigProvider
```

**Custom Provider Example:**

```java
public class VaultConfigProvider implements ConfigProvider {
    private VaultClient vault;

    @Override
    public ConfigData get(String path, Set<String> keys) {
        Map<String, String> data = new HashMap<>();

        for (String key : keys) {
            // Fetch from HashiCorp Vault
            String value = vault.read(path + "/" + key);
            data.put(key, value);
        }

        // TTL for caching
        return new ConfigData(data, 3600000L); // 1 hour
    }
}
```

---

## 10. Summary

**Security Checklist:**

```
Essential Security Measures:
──────────────────────────────────────────
✓ Authentication
  ├─ Use SSL or SASL (never PLAINTEXT in production)
  ├─ Prefer SCRAM or Kerberos
  └─ Enable reauthentication

✓ Encryption
  ├─ Use SSL/SASL_SSL for all external connections
  ├─ Encrypt disks storing sensitive data
  └─ Consider end-to-end encryption for PII

✓ Authorization
  ├─ Enable ACL authorizer
  ├─ Follow principle of least privilege
  ├─ Use prefixed ACLs for scale
  └─ Never use allow.everyone.if.no.acl.found=true

✓ Auditing
  ├─ Enable authorization logging
  ├─ Enable request logging
  ├─ Monitor for suspicious patterns
  └─ Integrate with SIEM

✓ ZooKeeper
  ├─ Enable SASL and/or SSL
  ├─ Enable ACLs (zookeeper.set.acl=true)
  └─ Isolate network access

✓ Platform
  ├─ Firewall Kafka ports
  ├─ Encrypt disks
  ├─ Protect key stores with file permissions
  └─ Externalize passwords
```

**Security Tiers by Use Case:**

```
Development/Testing:
├─ PLAINTEXT (local only)
└─ No ACLs

Internal Corporateuse:
├─ SASL_PLAINTEXT or SSL
├─ Basic ACLs
└─ File-based audit logs

Public Internet:
├─ SASL_SSL only
├─ Comprehensive ACLs
├─ Centralized audit logs
└─ Monitoring and alerting

Sensitive Data (PII, PHI, PCI):
├─ SASL_SSL with strong ciphers
├─ End-to-end encryption
├─ Strict ACLs with regular review
├─ Comprehensive auditing
├─ Encrypted storage
└─ Regular security audits
```

> **💡 Insight**
>
> Security is not one-time setup—it's ongoing maintenance. Rotate credentials regularly, review ACLs quarterly, update certificates before expiration, monitor logs continuously, and practice incident response procedures.

**Key Takeaways:**

1. **Defense in Depth**: Use multiple security layers
2. **Least Privilege**: Grant minimum necessary access
3. **Encrypt Everything**: Especially on untrusted networks
4. **Audit Everything**: Know who did what, when
5. **Secure the Platform**: Kafka is only as secure as its environment
6. **Plan for Incidents**: Assume breach, detect fast, respond faster

---

**Previous:** [← Chapter 10: Cross-Cluster Data Mirroring](./chapter10.md) | **Next:** [Chapter 12: Administering Kafka →](./chapter12.md)
