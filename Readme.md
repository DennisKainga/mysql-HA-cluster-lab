# High-Availability MySQL Cluster Lab

This laboratory environment establishes a production-grade, High-Availability (HA) MySQL infrastructure using **MySQL InnoDB Cluster** technology. It is designed to Help practise networked database cluster setup.

![MySQL InnoDB Cluster Architecture](/images/innodb_cluster_overview.png)
_(Standard InnoDB Cluster Topology: MySQL Shell, MySQL Router, and Group Replication)_

## 1. Project Objective & Official Standards

The goal of this lab is to move away from single-point-of-failure architectures by implementing the official [MySQL InnoDB Cluster](https://www.mysql.com/products/cluster/) stack.

By utilizing **Group Replication**, we ensure that data is synchronously replicated across three nodes. This setup leverages:

- **High Availability**: The system tolerates the failure of `(n-1)/2` nodes. In this 3-node lab, the system remains fully operational even if one node fails.
- **Elasticity**: New nodes can be added to the cluster with minimal configuration using the Built-in Clone Service.
- **Real-time Monitoring**: Integrated with MySQL Shell for advanced cluster administration.

## 2. Infrastructure Architecture

The stack is orchestrated via Docker Compose, utilizing the official [MySQL Router Docker Implementation](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-installation-docker.html) guidelines:

- **db1, db2, db3**: MySQL 8.0 nodes forming the Group Replication core.
- **mysql-router**: The intelligent layer-4 proxy. It handles "Metadata Caching" to track which node is the current `PRIMARY` (Read/Write) and which are `SECONDARY` (Read-Only).
- **cluster-setup**: A transient automation container running MySQL Shell 8.0. It executes `provision.js` to handle the bootstrap logic.

## 3. Configuration Details

### Database Nodes (The Engine)

Each node follows the requirements for InnoDB Cluster consistency:

- **GTID Mode**: `ON` (Global Transaction Identifiers) for consistent transaction tracking.
- **Enforce GTID Consistency**: `ON` to ensure only cluster-safe operations are executed.
- **Transaction Write Set Extraction**: Uses `XXHASH64` to identify and resolve conflicts during parallel replication.
- **Binary Logs**: `ROW` format as required by Group Replication for deterministic data consistency.

### MySQL Router (The Gateway)

Following the [official Docker documentation](https://dev.mysql.com/doc/mysql-router/8.0/en/mysql-router-installation-docker.html), the Router is "bootstrapped" against the cluster. It provides:

- **Port 6446**: Classic MySQL protocol for Read/Write traffic.
- **Port 6447**: Classic MySQL protocol for Read-Only traffic (load-balanced).
- **Metadata Cache**: Automatically updates the routing table when a failover occurs.

## 4. Key Modifications & Troubleshooting

Standard "out-of-the-box" configurations often fail in Docker-bridged environments. The following "First Principles" modifications were implemented:

### A. Authentication Plugin "Handshake" Fix

**Issue**: Tools like phpMyAdmin and Adminer experienced infinite "hanging" during login.
**Root Cause**: MySQL 8.0 defaults to `caching_sha2_password`. The "double-hop" (Client -> Router -> DB) often stutters during the RSA key exchange in virtualized networks.
**Modification**: Set `--default-authentication-plugin=mysql_native_password` in the `mysqld` startup command for all nodes.

### B. DNS Resolution Optimization (`skip_name_resolve`)

**Issue**: Router logs showed `closed connection before finishing handshake`.
**Modification**: MySQL nodes were configured with `skip_name_resolve`. This bypasses the overhead of reverse DNS lookups for internal Docker IP addresses (`172.18.x.x`), preventing handshake timeouts.

### C. Router Configuration Persistence

**Modification**: Mounted a volume to `/tmp/mysqlrouter`. This ensures the Router retains its generated `keyring` and `mysqlrouter.conf` across restarts, preventing "Metadata out of sync" errors.

## 5. Automation Logic (`provision.js`)

The `cluster-setup` container follows this automated lifecycle:

1.  **Handshake**: Establishes a session with the seed node (`db1`).
2.  **Cluster Discovery**: Attempts `dba.getCluster('SophionicCluster')`.
3.  **Bootstrapping**: If missing, it runs `dba.configureInstance` on all targets to verify prerequisites.
4.  **Cloning**: Adds `db2` and `db3` using the **Clone Recovery Method**, which physically copies the data files for near-instant synchronization.
5.  **Graceful Exit**: Uses `shell.exit(0)` to signal to Docker Compose that the infrastructure is ready, allowing the `router` to start.

## 6. How to Use

1.  **Deploy**: `docker compose up -d`
2.  **Visualize**: on the browser visit `localhost:8080` This opens phpMyAdmin
3.  **Access Management**:
    - **Direct Access**: `localhost:3306` (Primary node only).
    - **Routed Access (Recommended)**: `localhost:6446` (Always points to whichever node is currently the Primary).
4.  **Verify HA Status**:
    ```bash
    docker exec -it cluster-setup mysqlsh --uri root@db1:3306 --password=password --js -e "dba.getCluster('SophionicCluster').status()"
    ```
