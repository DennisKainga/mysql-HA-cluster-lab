# High-Availability MySQL Cluster Lab

This laboratory environment establishes a production-grade, High-Availability (HA) MySQL infrastructure using **MySQL InnoDB Cluster** technology. It is designed to help practice networked database cluster setups.

<!-- <div align="center">
 <img src="/images/innodb_cluster_overview.png" 
     alt="MySQL InnoDB Cluster Architecture" 
     style="height: 400px; width: 50%; object-fit: contain;">
  <p><i>Standard InnoDB Cluster Topology: MySQL Shell, MySQL Router, and Group Replication</i></p>
</div> -->
<p align="center">
  <img src="/images/innodb_cluster_overview.png" alt="Docker banner" style="max-width: 100%; width: 600px;" />
 <i>Standard InnoDB Cluster Topology: MySQL Shell, MySQL Router, and Group Replication</i>
</p>
---

## Table of Contents

1. [Project Objective & Official Standards](#1-project-objective--official-standards)
2. [Infrastructure Architecture](#2-infrastructure-architecture)
3. [Configuration Details](#3-configuration-details)
   - [Database Nodes](#database-nodes-the-engine)
   - [MySQL Router](#mysql-router-the-gateway)
4. [Key Modifications & Troubleshooting](#4-key-modifications--troubleshooting)
   - [Authentication Fix](#a-authentication-plugin-handshake-fix)
   - [DNS Optimization](#b-dns-resolution-optimization-skip_name_resolve)
   - [Router Persistence](#c-router-configuration-persistence)
5. [Automation Logic (provision.js)](#5-automation-logic-provisionjs)
6. [How to Use](#6-how-to-use)

---

## 1. Project Objective & Official Standards

The goal of this lab is to move away from single-point-of-failure architectures by implementing the official [MySQL InnoDB Cluster](https://dev.mysql.com/doc/mysql-shell/9.6/en/mysql-innodb-cluster.html) stack.

By utilizing **Group Replication**, we ensure that data is synchronously replicated across three nodes. This setup leverages:

- **High Availability**: The system tolerates the failure of `(n-1)/2` nodes. In this 3-node lab, the system remains fully operational even if one node fails.
- **Elasticity**: New nodes can be added to the cluster with minimal configuration using the Built-in Clone Service.
- **Real-time Monitoring**: Integrated with MySQL Shell for advanced cluster administration.

## 2. Infrastructure Architecture

The stack is orchestrated via Docker Compose, utilizing official [MySQL Router Docker Implementation](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-installation-docker.html) guidelines:

- **db1, db2, db3**: MySQL 8.0 nodes forming the Group Replication core.
- **mysql-router**: The intelligent layer-4 proxy. It handles "Metadata Caching" to track which node is the current `PRIMARY` (Read/Write) and which are `SECONDARY` (Read-Only).
- **cluster-setup**: A transient automation container running MySQL Shell 8.0. It executes `provision.js` to handle the bootstrap logic.

## 3. Configuration Details

### Database Nodes (The Engine)

Each node follows the requirements for InnoDB Cluster consistency:

- **GTID Mode**: `ON` (Global Transaction Identifiers) for consistent transaction tracking.
- **Enforce GTID Consistency**: `ON` to ensure only cluster-safe operations are executed.
- **Transaction Write Set Extraction**: Uses `XXHASH64` to identify and resolve conflicts during parallel replication.
- **Binary Logs**: `ROW` format as required by Group Replication.

### MySQL Router (The Gateway)

Following [official documentation](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-installation-docker.html), the Router is bootstrapped against the cluster:

- **Port 6446**: Classic MySQL protocol for Read/Write traffic.
- **Port 6447**: Classic MySQL protocol for Read-Only traffic (load-balanced).
- **Metadata Cache**: Automatically updates the routing table when a failover occurs.

## 4. Key Modifications & Troubleshooting

Standard "out-of-the-box" configurations often fail in Docker-bridged environments. The following modifications were implemented:

### A. Authentication Plugin "Handshake" Fix

- **Issue**: Tools like phpMyAdmin and Adminer experienced infinite "hanging" during login.
- **Root Cause**: MySQL 8.0 defaults to `caching_sha2_password`. The "double-hop" (Client -> Router -> DB) often stutters during the RSA key exchange in virtualized networks.
- **Modification**: Set `--default-authentication-plugin=mysql_native_password` in the `mysqld` startup command for all nodes.

### B. DNS Resolution Optimization (`skip_name_resolve`)

- **Issue**: Router logs showed `closed connection before finishing handshake`.
- **Modification**: MySQL nodes were configured with `skip_name_resolve`. This bypasses the overhead of reverse DNS lookups for internal Docker IP addresses, preventing handshake timeouts.

### C. Router Configuration Persistence

- **Modification**: Mounted a volume to `/tmp/mysqlrouter`. This ensures the Router retains its generated `keyring` and configuration across restarts, preventing "Metadata out of sync" errors.

## 5. Automation Logic (`provision.js`)

The `cluster-setup` container follows this automated lifecycle:

1. **Handshake**: Establishes a session with the seed node (`db1`).
2. **Cluster Discovery**: Attempts `dba.getCluster('SophionicCluster')`.
3. **Bootstrapping**: If missing, it runs `dba.configureInstance` on all targets to verify prerequisites.
4. **Cloning**: Adds `db2` and `db3` using the **Clone Recovery Method** for near-instant synchronization.
5. **Graceful Exit**: Uses `shell.exit(0)` to signal that infrastructure is ready, allowing the `router` to start.

## 6. How to Use & Seed Data

### A. Seeding the Cluster

The lab includes a `Makefile` to automate the creation of the `library_lab` database (Authors, Books, and Comments).

1. **Deploy the stack**: `docker compose up -d`
2. **Run the seed command**:
   ```bash
   make seed
   ```
   _This command pipes `demo.sql` through the **Router (Port 6446)**. The Router identifies the current Primary node and ensures the write is replicated across the entire cluster._

### B. Visualizing Data Consistency

To verify that the data is truly replicated, visit **phpMyAdmin** at `localhost:8080`.

1. Use the **Server Choice** dropdown to select `db1`.
2. Check the `library_lab` tables.
3. Switch the dropdown to `db2` or `db3`. You will see the **exact same data**, proving that Group Replication is working in the background.
<div align="center">
 <img src="/images/select_server.png" 
     alt="MySQL InnoDB Cluster Architecture" 
     style="height: 280px; width: 50%; object-fit: contain;">
</div>

---

## 7. Validating High Availability (The "Stress Test")

To truly understand how the the Cluster protects your data, perform the following architectural tests:

### Test 1: Write Protection on Secondaries (Slaves)

The InnoDB Cluster enforces a "Single-Primary" mode by default.

- **Action**: Log into `db2` or `db3` via phpMyAdmin and try to manually insert a row into the `authors` table.
- **Expected Result**: MySQL will throw an error:
  `ERROR 1290 (HY000): The MySQL server is running with the --super-read-only option so it cannot execute this statement.`
- **Lesson**: This prevents data drift. All writes **must** go through the Router or the designated Primary.
<div align="center">
 <img src="/images/writeprotect.png" 
     alt="MySQL InnoDB Cluster Architecture" 
     style="height: 280px; width: 50%; object-fit: contain;">
</div>

### Test 2: Automatic Failover & Zero Downtime

- **Action**: Stop the current Primary node (e.g., `docker stop db1`).
- **Observation**:
  1. Use `make status` to see the cluster state. You will notice `db1` is "OFFLINE" and either `db2` or `db3` has been automatically promoted to **PRIMARY**.
  2. Access the data via the **Router (Port 6446)**.
- **Expected Result**: Your application remains fully functional. The Router automatically re-routes your connection to the new Primary in milliseconds.
- **Lesson**: Your data remains accessible and writable even during hardware failure.

### Test 3: Self-Healing Cluster

- **Action**: Restart the stopped node: `docker start db1`.
- **Observation**: The node will move from "OFFLINE" to "RECOVERING" and finally back to "ONLINE".
- **Expected Result**: `db1` will automatically pull any missing transactions from the other nodes (via the Clone Service) to catch up.
- **Lesson**: The cluster is self-healing; manual data restoration is not required.
