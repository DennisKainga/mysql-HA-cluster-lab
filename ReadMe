# Sophionic High-Availability MySQL Cluster Lab
This laboratory environment establishes a production-grade, High-Availability (HA) MySQL infrastructure using **InnoDB Cluster** technology. It is designed to provide the database backbone for the Sophionic multi-tenant ERP system, ensuring zero data loss and automatic failover.

## 1. Project Objective
The goal of this lab was to move away from a single-point-of-failure database architecture. By utilizing **Group Replication**, we ensure that data is synchronously replicated across three nodes, allowing the system to tolerate the failure of at least one node without manual intervention or data corruption.

## 2. Infrastructure Architecture
The stack is composed of five specialized containers orchestrated via Docker Compose:

* **db1, db2, db3**: MySQL 8.0 nodes forming the InnoDB Cluster.
* **mysql-router**: The intelligent layer-4 proxy that routes application traffic to the current Primary (Read/Write) or Secondaries (Read-Only).
* **cluster-setup**: A transient automation container that uses MySQL Shell and JavaScript (`provision.js`) to bootstrap the cluster.

## 3. Configuration Details

### Database Nodes
Each node is configured with specific InnoDB Cluster requirements:
- **GTID Mode**: Enabled for consistent transaction tracking across the cluster.
- **Enforce GTID Consistency**: Strict enforcement to prevent non-transactional updates that break replication.
- **Transaction Write Set Extraction**: Uses `XXHASH64` for high-performance conflict detection during multi-master arbitration.

## 4. Key Modifications & Troubleshooting
The following critical adjustments were made to the standard configuration to resolve performance and connectivity issues encountered during the lab:

### A. Authentication Plugin "Handshake" Fix
**Issue**: Tools like phpMyAdmin and Adminer experienced infinite "hanging" during login attempts through the Router.
**Root Cause**: MySQL 8.0 defaults to `caching_sha2_password`, which requires a complex secure handshake that often stutters when proxied through a Docker-bridged Router.
**Modification**: Reverted the default authentication to `mysql_native_password`. 
```yaml
command: ["mysqld", "--default-authentication-plugin=mysql_native_password", ...]
```

### B. DNS Resolution Optimization
**Issue**: The Router logs showed "closed connection before finishing handshake" errors.
**Modification**: Implemented `skip_name_resolve` on the database nodes. This prevents MySQL from attempting to perform reverse DNS lookups on incoming connections from the Docker network, significantly speeding up the handshake.

### C. Router Persistence
**Modification**: The Router is configured to bootstrap once and reuse the configuration. This prevents the "Keyring" conflicts that occur if a Router tries to re-register with an already initialized cluster.

## 5. Automation Logic (`provision.js`)
The `cluster-setup` container executes a JavaScript file via MySQL Shell that performs the following "First Principles" logic:
1.  **Connect**: Establishes a session with `db1`.
2.  **Detection**: Checks if `SophionicCluster` already exists in the metadata.
3.  **Initialization**: If new, it runs `dba.configureInstance` on all nodes and executes `dba.createCluster`.
4.  **Scaling**: Dynamically adds `db2` and `db3` using the `CLONE` recovery method, which is faster than traditional incremental recovery for new nodes.
5.  **Termination**: The script utilizes `shell.exit(0)` upon completion to allow Docker to gracefully stop the setup container while the database remains online.

## 6. How to Use
1.  **Start the Stack**: `docker compose up -d`
2.  **Access Management**: 
    * **Direct Access**: Use `localhost:3306` (to `db1`) for high-level admin tasks.
    * **Routed Access**: Use `localhost:6446` for Read/Write traffic (App traffic).
3.  **Monitor Status**: 
    ```bash
    docker exec -it cluster-setup mysqlsh --uri root@db1:3306 --password=password --js -e "dba.getCluster('SophionicCluster').status()"
    ```